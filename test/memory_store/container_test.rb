require 'test_helper'
require 'circuitbox/memory_store/container'

class MemoryStoreContainerTest < Minitest::Test
  def test_initialize_sets_the_value
    container = Circuitbox::MemoryStore::Container.new(value: 'test')
    assert_equal 'test', container.value
  end

  def test_initialize_sets_default_expiry
    Circuitbox::MemoryStore::Container.any_instance
                                      .expects(:expires_after)
                                      .with(0)

    Circuitbox::MemoryStore::Container.new(value: 'test')
  end

  def test_initialize_sets_custom_expiry
    Circuitbox::MemoryStore::Container.any_instance
                                      .expects(:expires_after)
                                      .with(5)

    Circuitbox::MemoryStore::Container.new(value: 'test', expiry: 5)
  end

  def test_expired_returns_false_when_expiry_is_zero
    container = Circuitbox::MemoryStore::Container.new(value: 'test')
    container.expects(:current_second).never

    assert_equal false, container.expired?
  end

  def test_expired_returns_false_when_value_is_still_valid
    container = Circuitbox::MemoryStore::Container.new(value: 'test', expiry: 1)
    container.expects(:current_second).returns(2).twice
    container.expires_after(2)

    assert_equal false, container.expired?
  end

  def test_expired_returns_true_when_value_has_expired
    container = Circuitbox::MemoryStore::Container.new(value: 'test')
    container.expects(:current_second).returns(1)
    container.expires_after(5)

    # move the time up to after the value should expire
    container.expects(:current_second).returns(7)

    assert container.expired?
  end
end
