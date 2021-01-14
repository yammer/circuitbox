# frozen_string_literal: true

require 'test_helper'
require 'circuitbox/memory_store'

class MemoryStoreTest < Minitest::Test
  def setup
    @memory_store = Circuitbox::MemoryStore.new
  end

  def test_store_returns_value_being_stored
    return_value = @memory_store.store('test', 5)
    assert_equal 5, return_value
  end

  def test_store_default_expires_zero
    Circuitbox::MemoryStore::Container.expects(:new)
                                      .with(value: 5, expiry: 0)
    @memory_store.store('test', 5)
  end

  def test_store_allows_custom_expires
    Circuitbox::MemoryStore::Container.expects(:new)
                                      .with(value: 5, expiry: 10)
    @memory_store.store('test', 5, expires: 10)
  end

  def test_increment_default_amount_is_one
    return_value = @memory_store.increment('test')
    assert_equal 1, return_value
  end

  def test_increment_allows_custom_amount
    return_value = @memory_store.increment('test', 5)
    assert_equal 5, return_value
  end

  def test_increment_can_be_called_on_existing_key
    @memory_store.store('test', 1)
    assert_equal 2, @memory_store.increment('test')
  end

  def test_increment_passes_expires_to_container
    Circuitbox::MemoryStore::Container.expects(:new)
                                      .with(value: 1, expiry: 2)

    @memory_store.increment('test', 1, expires: 2)
  end

  def test_increment_default_expires_is_zero
    Circuitbox::MemoryStore::Container.expects(:new)
                                      .with(value: 1, expiry: 0)

    @memory_store.increment('test')
  end

  def test_increment_updates_expires_on_existing_key
    container = mock
    container.stubs(:expired_at? => false, :value => 1, :value= => 2)
    container.expects(:expires_after).with(5)

    Circuitbox::MemoryStore::Container.stubs(:new)
                                      .returns(container)

    @memory_store.increment('test') # creates new key
    @memory_store.increment('test', 1, expires: 5) # updates existing key
  end

  def test_increment_compacts_store
    current_second = @memory_store.send(:current_second)
    @memory_store.stubs(:current_second).returns(current_second + 61)

    @memory_store.expects(:compact)

    @memory_store.increment('test')
  end

  def test_load_returns_the_value_of_a_key
    @memory_store.store('test', 1234)
    assert_equal 1234, @memory_store.load('test')
  end

  def test_load_returns_nil_when_key_not_set
    assert_nil @memory_store.load('test')
  end

  def test_load_returns_nil_when_key_expired
    container = mock
    container.stubs(:value= => 1234, :value => 1234)
    Circuitbox::MemoryStore::Container.stubs(:new)
                                      .returns(container)
    @memory_store.store('test', 1234)

    container.expects(:expired_at?).returns(true)

    assert_nil @memory_store.load('test')
  end

  def test_load_compacts_store
    current_second = @memory_store.send(:current_second)
    @memory_store.stubs(:current_second).returns(current_second + 61)

    @memory_store.expects(:compact)

    @memory_store.load('test')
  end

  def test_key_returns_true_when_key_is_set
    @memory_store.store('test', 1)
    assert @memory_store.key?('test')
  end

  def test_key_returns_false_when_key_is_not_set
    refute @memory_store.key?('test')
  end

  def test_key_returns_false_when_key_is_expired
    container = mock
    container.stubs(:value= => 1, :value => 1)
    Circuitbox::MemoryStore::Container.stubs(:new)
                                      .returns(container)
    @memory_store.store('test', 1)
    container.expects(:expired_at?).returns(true)
    refute @memory_store.key?('test')
  end

  def test_key_compacts_store
    current_second = @memory_store.send(:current_second)
    @memory_store.stubs(:current_second).returns(current_second + 61)

    @memory_store.expects(:compact)

    @memory_store.key?('test')
  end

  def test_delete_removes_key
    @memory_store.store('test', 1)

    @memory_store.delete('test')
    refute @memory_store.key?('test')
  end
end
