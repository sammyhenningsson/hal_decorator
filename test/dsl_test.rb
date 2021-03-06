require 'test_helper'
require 'ostruct'

class DSLTest < ActiveSupport::TestCase
  def setup
    @obj = OpenStruct.new(
      from_object: 'string_from_obj'.freeze,
      from_block: 'string_from_block'.freeze
    )
    @serializer = Class.new { extend HALPresenter }
  end

  test 'model' do
    Model = Struct.new(:title)
    @serializer.model Model
    resource = Model.new(title: 'some title')
    assert_equal @serializer, HALPresenter.lookup_presenter(resource)
  end

  test 'policy' do
    p = Class.new
    @serializer.policy p
    assert_equal p, @serializer.send(:policy_class)
  end

  test 'profile defaults to nil' do
    assert_nil @serializer.semantic_profile
  end

  test 'profile with value from contant' do
    @serializer.profile 'foobar'
    assert_equal 'foobar', @serializer.semantic_profile
    assert_equal 'foobar', @serializer.semantic_profile(@obj)
  end

  test 'profile with value from block' do
    @serializer.profile { resource.from_block }
    assert_equal 'string_from_block', @serializer.semantic_profile(@obj)
  end

  test 'profile can be inherited' do
    @serializer.profile 'foobar'
    child = Class.new(@serializer)
    assert_equal 'foobar', child.semantic_profile(@obj)
  end

  test 'attribute with value from contant' do
    @serializer.attribute :from_constant, 'some_string'.freeze
    attribute = @serializer.send(:attributes).first
    assert_instance_of HALPresenter::Property, attribute
    assert_equal :from_constant, attribute.name
    assert_equal 'some_string', attribute.value('ignore'.freeze)
  end

  test 'attribute with value from object' do
    @serializer.attribute :from_object
    attribute = @serializer.send(:attributes).first
    assert_instance_of HALPresenter::Property, attribute
    assert_equal :from_object, attribute.name
    assert_equal 'string_from_obj', attribute.value(@obj)
  end

  test 'attribute with value from block' do
    @serializer.attribute(:from_block) { resource.from_block }
    attribute = @serializer.send(:attributes).first
    assert_instance_of HALPresenter::Property, attribute
    assert_equal :from_block, attribute.name
    assert_equal 'string_from_block' , attribute.value(@obj)
  end

  test 'link with value from contant' do
    @serializer.link :from_constant, 'some_string'.freeze
    link = @serializer.send(:links).last
    assert_instance_of HALPresenter::Links::Link, link
    assert_equal :from_constant, link.name
    assert_equal 'some_string' , link.value('ignore'.freeze)
  end

  test 'link with value from block' do
    @serializer.link(:from_block) { resource.from_block }
    link = @serializer.send(:links).first
    assert_instance_of HALPresenter::Links::Link, link
    assert_equal :from_block, link.name
    assert_equal 'string_from_block' , link.value(@obj)
  end

  test 'link with title' do
    @serializer.link(:with_method, title: 'hello') { 'resource/1/edit' }
    link = @serializer.send(:links).first
    assert_instance_of HALPresenter::Links::Link, link
    assert_equal :with_method, link.name
    assert_equal 'resource/1/edit' , link.value(@obj)
    assert_equal 'hello', link.title
  end

  test 'link with deprecation' do
    @serializer.link(:with_deprecation, deprecation: true) { 'resource/1/edit' }
    link = @serializer.send(:links).first
    assert_instance_of HALPresenter::Links::Link, link
    assert_equal 'resource/1/edit' , link.value(@obj)
    assert link.deprecation
  end

  test 'link must have a constant or block' do
    assert_raises RuntimeError do
      @serializer.link :no_good
    end
  end

  test 'curie with value from contant' do
    @serializer.curie :from_constant, 'some_string'.freeze
    curie = @serializer.send(:curies).last
    assert_instance_of HALPresenter::Curie, curie
    assert_equal :from_constant, curie.name
    assert_equal 'some_string' , curie.value('ignore'.freeze)
  end

  test 'curie with value from block' do
    @serializer.curie(:from_block) { resource.from_block }
    curie = @serializer.send(:curies).first
    assert_instance_of HALPresenter::Curie, curie
    assert_equal :from_block, curie.name
    assert_equal 'string_from_block' , curie.value(@obj)
  end

  test 'curie must have a constant or block' do
    assert_raises RuntimeError do
      @serializer.curie :no_good
    end
  end

  test 'embed with value from contant' do
    @serializer.embed :from_constant, OpenStruct.new(title: 'from_constant').freeze
    embed = @serializer.send(:embedded).first
    assert_instance_of HALPresenter::Embedded::Embed, embed
    assert_equal :from_constant, embed.name
    assert_instance_of OpenStruct , embed.value('ignored'.freeze)
    assert_equal 'from_constant', embed.value.title
  end

  test 'embed with value from object' do
    @serializer.embed :from_object
    embed = @serializer.send(:embedded).first
    assert_instance_of HALPresenter::Embedded::Embed, embed
    assert_equal :from_object, embed.name
    assert_equal 'string_from_obj', embed.value(@obj)
  end

  test 'embed with value from block' do
    @serializer.embed :from_block do
      resource.from_block
    end
    embed = @serializer.send(:embedded).first
    assert_instance_of HALPresenter::Embedded::Embed, embed
    assert_equal :from_block, embed.name
    assert_equal 'string_from_block' , embed.value(@obj)
  end

  test 'embed with specified presenter' do
    EmbeddedSerializer = Struct.new(:name)
    @serializer.embed :from_block, presenter_class: EmbeddedSerializer do
      {foo: 2}
    end
    embed = @serializer.send(:embedded).first
    assert_instance_of HALPresenter::Embedded::Embed, embed
    assert_equal :from_block, embed.name
    assert_equal({foo: 2}, embed.value)
    assert_equal EmbeddedSerializer, embed.presenter_class
  end

  test 'collection with block' do
    @serializer.collection of: 'items' do
      attribute :collection_attribute
      link :collection_link, '/'
      curie :collection_curie, '/'
    end

    collection = @serializer.send(:collection_properties)
    assert_instance_of HALPresenter::Collection::Properties, collection
    assert_equal 'items', collection.name
    assert_equal 1, collection.send(:attributes).size
    assert_equal 1, collection.send(:links).size
    assert_equal 1, collection.send(:curies).size
  end

  test 'collection must have a "of" keyword argument' do
    assert_raises ArgumentError do
      @serializer.collection do
        attribute :collection_attribute
      end
    end

  end

  test 'post_serialize hook' do
    @serializer.post_serialize do |hash|
      hash[:added] = 'more'
    end
    hook = @serializer.send(:post_serialize_hook)
    assert_instance_of HALPresenter::SerializeHooks::Hook, hook
    serialized = { foo: 5 }
    hook.run(nil, nil, serialized)
    assert_equal({foo: 5, added: 'more' }, serialized)
  end
end
