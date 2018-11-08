require 'test_helper'
require 'circuitbox/memory_store'

class MemoryStoreTest < Minitest::Test
  def setup
    @memory_store = Circuitbox::MemoryStore.new
  end

  def test_load_returns_nil_when_expired
    @memory_store.store('test_key', 'test_value', expires: 1)

    sleep 2

    assert_nil @memory_store.load('test_key')
  end

  def test_load_returns_value_when_not_expired
    @memory_store.store('test_key', 'test_value', expires: 10)

    assert_equal 'test_value', @memory_store.load('test_key')
  end

  def test_key_returns_false_when_expired
    @memory_store.store('test_key', 'test_value', expires: 1)

    sleep 2

    assert_equal false, @memory_store.key?('test_key')
  end

  def test_key_returns_true_when_not_expired
    @memory_store.store('test_key', 'test_value', expires: 10)

    assert @memory_store.key?('test_key')
  end
end
