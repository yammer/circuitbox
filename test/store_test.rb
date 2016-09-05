require "test_helper"
require "tempfile"

class Circuitbox
  class StoreTest < Minitest::Test

    def test_create_in_memory_store
      behaves_like_circuit_store Store.in_process_store
    end

    def test_create_cross_process_store
      Tempfile.open("daybreak_file") do |file|
        store = Store.cross_process_store(file)
        behaves_like_circuit_store store
        store.close
      end
    end

    def behaves_like_circuit_store(circuit_store)
      circuit_store.store("key", "1", expires: 1000)
      circuit_store.store("int", "1", raw: true)
      circuit_store.load("int", raw: true)
      circuit_store.increment("int")
      circuit_store.delete("key")
    end

    def test_loads_changes_from_cross_process_interaction_on_access
      store = mock("store")
      store.expects(:increment).at_least_once
      store.expects(:[]).at_least_once
      store.expects(:load).at_least_once

      backend = mock("backend")
      store.expects(:adapter).returns(stub(backend: backend)).at_least_once
      backend.expects(:load).times(3)

      daybreak_store = DaybreakCrossProcessStore.new(store)

      daybreak_store.increment("key")
      daybreak_store["key"]
      daybreak_store.load("key")
    end

    def test_autocompacting_calls_compact_after_1000_ops
      store = mock("store")
      store.expects(:store).at_least_once
      store.expects(:delete).at_least_once
      store.expects(:increment).at_least_once

      backend = mock("backend")
      store.expects(:adapter).returns(stub(backend: backend)).at_least_once
      backend.expects(:compact)
      backend.expects(:load).at_least_once

      daybreak_store = DaybreakCrossProcessStore.new(store)

      335.times { daybreak_store.store("key", "value") }
      335.times { daybreak_store.delete("key") }
      335.times { daybreak_store.increment("key") }
    end

    def test_allows_configuration_for_when_to_compact
      store = mock("store")
      store.expects(:store).at_least_once

      backend = mock("backend")
      store.expects(:adapter).returns(stub(backend: backend)).at_least_once
      backend.expects(:compact)

      always_compact = lambda { |_| true }
      daybreak_store = DaybreakCrossProcessStore.new(store, always_compact)

      daybreak_store.store("key", "value")
    end
  end
end
