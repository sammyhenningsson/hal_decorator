# frozen_string_literal: true

module HALPresenter
  class LazyEvaluator
    attr_reader :resource, :options
    alias resources resource

    def initialize(block)
      @__context = eval 'self', block.binding
      define_singleton_method(:evaluate_block, &block)
    end

    def update_context(context)
      @__context = context
    end

    def evaluate(resource, options)
      @resource = resource
      @options = options || {}
      evaluate_block
    ensure
      @resource = nil
      @options = nil
    end

    private

    attr_reader :__context

    def method_missing(method, *args, &block)
      return super unless __context.respond_to?(method)

      define_singleton_method(method) do |*a, &b|
        __context.public_send(method, *a, &b)
      end

      public_send(method, *args, &block)
    end

    def respond_to_missing?(method, _include_private = false)
      __context.respond_to?(method) || super
    end
  end
end