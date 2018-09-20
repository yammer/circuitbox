require 'test_helper'
require 'circuitbox/memory_store/compactor'

class MemoryStoreCompactorTest < Minitest::Test
  def test_initialize_sets_store
    store = mock
    compactor = Circuitbox::MemoryStore::Compactor.new(store: store, frequency: 1)
    assert_equal store, compactor.store
  end

  def test_initialize_sets_frequency
    compactor = Circuitbox::MemoryStore::Compactor.new(store: {}, frequency: 2)
    assert_equal 2, compactor.frequency
  end

  def test_initialize_sets_compact_after
    Circuitbox::MemoryStore::Compactor.any_instance
                                      .stubs(:current_second)
                                      .returns(1)

    compactor = Circuitbox::MemoryStore::Compactor.new(store: {}, frequency: 2)
    assert_equal 3, compactor.compact_after
  end

  def test_run_does_not_compact_when_compact_after_has_not_passed
    store = mock
    compactor = Circuitbox::MemoryStore::Compactor.new(store: store, frequency: 2)

    current_second = compactor.compact_after - 1

    compactor.stubs(:current_second).returns(current_second)
    store.expects(:delete_if).never

    compactor.run
  end

  def test_run_checks_if_value_is_expired_when_compacting
    value_mock = mock
    value_mock.expects(:expired?).returns(true)
    store = { 'test' => value_mock }

    compactor = Circuitbox::MemoryStore::Compactor.new(store: store, frequency: 2)

    compactor.stubs(:current_second).returns(compactor.compact_after + 1)

    compactor.run
  end

  def test_run_sets_compact_after_when_compaction_complete
    Circuitbox::MemoryStore::Compactor.any_instance
                                      .stubs(:current_second)
                                      .returns(1)
    store = mock
    store.stubs(:delete_if)

    compactor = Circuitbox::MemoryStore::Compactor.new(store: store, frequency: 2)

    current_second = compactor.compact_after + 1
    compactor.stubs(:current_second).returns(compactor.compact_after + 1)

    compactor.run

    assert_equal current_second + 2, compactor.compact_after
  end
end
