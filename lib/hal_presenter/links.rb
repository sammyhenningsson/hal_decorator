require 'hal_presenter/property'
require 'hal_presenter/super_init'

module HALPresenter
  module Links
    include SuperInit

    module ClassMethods
      def base_href=(base)
        @base_href = base&.sub(%r(/*$), '')
      end

      def href(href)
        return href if (@base_href ||= '').empty?
        return href if href =~ %r(\A(\w+://)?[^/])
        @base_href + href
      end
    end

    class Link < HALPresenter::Property
      attr_reader :type, :deprecation, :profile, :title
      attr_accessor :templated

      alias rel name

      def initialize(rel, value = NO_VALUE, **kwargs, &block)
        @type =         kwargs[:type].freeze
        @deprecation =  kwargs[:deprecation].freeze
        @profile =      kwargs[:profile].freeze
        @title =        kwargs[:title].freeze

        curie = kwargs[:curie].to_s
        rel = [curie, rel.to_s].join(':') unless curie.empty?

        super(
          rel,
          value,
          embed_depth: kwargs[:embed_depth],
          context: kwargs[:context],
          &block
        )
      end

      def to_h(resource = nil, options = {})
        href = value(resource, options)
        return {} unless href

        {href: HALPresenter.href(href)}.tap do |hash|
          hash[:type]        = type        if type
          hash[:deprecation] = deprecation if deprecation
          hash[:profile]     = profile     if profile
          hash[:title]       = title       if title
          hash[:templated]   = templated   if templated
        end
      end
    end

    def self.included(base)
      base.extend ClassMethods
    end

    def link(rel, value = nil, **kwargs, &block)
      if value.nil? && !block_given?
        raise 'link must be called with non nil value or be given a block'
      end

      kwargs[:context] ||= self
      rel = rel.to_sym

      if rel == :self || kwargs[:replace_parent]
        links.delete_if { |link| link.rel == rel }
      end

      Link.new(rel, value, **kwargs, &block).tap do |link|
        links << link
      end
    end

    protected

    def links
      @__links ||= __init_from_superclass(:links)
    end
  end
end
