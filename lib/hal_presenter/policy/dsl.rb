module HALPresenter
  module Policy
    module DSL

      class Rules

        def attributes
          @attributes ||= Hash.new(Proc.new { false })
        end

        def links
          @links ||= Hash.new(Proc.new { false })
        end

        def embedded
          @embedded ||= Hash.new(Proc.new { false })
        end

        private :attributes, :links, :embedded

        def defaults(*types, value: false)
          types.each do |t|
            send(t).default= Proc.new { value }
          end
        end

        def attribute_rule_for(name)
          attributes[name]
        end

        def add_attribute(name, block)
          attributes[name] = block
        end

        def link_rule_for(rel)
          links[rel]
        end

        def add_link(rel, block)
          links[rel] = block
        end

        def embed_rule_for(name)
          embedded[name]
        end

        def add_embed(name, block)
          embedded[name] = block
        end

      end

      module ClassMethods

        def allow_by_default(*types)
          rules.defaults(*types, value: true)
        end

        def attribute(*names)
          b = block_given? ? Proc.new : Proc.new { true }
          names.each { |name| rules.add_attribute(name, b) }
        end

        def link(*rels)
          b = block_given? ? Proc.new : Proc.new { true }
          rels.each { |rel| rules.add_link(rel, b) }
        end

        def embed(*names)
          b = block_given? ? Proc.new : Proc.new { true }
          names.each { |name| rules.add_embed(name, b) }
        end

        def rules
          @rules ||= Rules.new
        end

      end

      def self.included(mod)
        mod.extend(ClassMethods)
      end

      def initialize(current_user, resource, options = {})
        @current_user = current_user
        @resource = resource
        @options = options
      end

      def attribute?(name)
        run self.class.rules.attribute_rule_for(name)
      end

      def link?(rel)
        return true if rel == :self
        run self.class.rules.link_rule_for(rel)
      end

      def embed?(name)
        run self.class.rules.embed_rule_for(name)
      end

      private

      attr_reader :current_user, :resource, :options

      def run(block)
        instance_eval(&block) && true || false
      end

    end
  end
end
