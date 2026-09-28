# frozen_string_literal: true

module Awfy
  module Rails
    module Collectors
      # Counts Elasticsearch requests at the transport level: every request that goes through
      # Elastic::Transport::Client#perform_request (the client under the elasticsearch gem and
      # the wrappers built on it). Searches, counts, aggregations and bulk writes are all
      # transport requests, so this also sees calls that fire no ActiveSupport notification.
      #
      # The first collector that starts while the transport class is defined prepends
      # Instrumentation to it, once per process. Without the gem, the collector records zero
      # requests and "transport" => false. Only requests on the thread that started the
      # collector count.
      class Elasticsearch < Awfy::Collector
        ACTIVE_KEY = :awfy_elasticsearch_collector
        # A document id follows these API segments; it is replaced with ":id".
        ID_AFTER = %w[_doc _create _update _source _explain _termvectors].freeze

        module Instrumentation
          def perform_request(method, path, *, &)
            Awfy::Rails::Collectors::Elasticsearch.current&.record(method, path)
            super
          end
        end

        class << self
          attr_writer :target

          def key = "elasticsearch"

          def metrics(data) = {"requests" => data["requests"]}.merge(data.fetch("by_path", {}))

          def current = Thread.current[ACTIVE_KEY]

          # The class to instrument: the one set for tests, else elastic-transport's client.
          def target
            return @target if @target

            ::Elastic::Transport::Client if defined?(::Elastic::Transport::Client)
          end

          # Prepends Instrumentation once. Returns whether a transport class is instrumented.
          def install!
            klass = target or return false
            klass.prepend(Instrumentation) unless klass.ancestors.include?(Instrumentation)
            true
          end

          # Keeps the index or alias (a run of 6 or more digits, as in a timestamped index name,
          # becomes "*") and every "_" API segment, replaces a document id with ":id", and drops
          # the query string: "/orders_20260924120000/_search?x=1" -> "/orders_*/_search".
          def normalize_path(path)
            segments = path.to_s.split("?", 2).first.to_s.split("/").reject(&:empty?)
            normalized = segments.each_with_index.map do |segment, i|
              if segment.start_with?("_")
                segment
              elsif i.zero?
                segment.gsub(/\d{6,}/, "*")
              elsif ID_AFTER.include?(segments[i - 1])
                ":id"
              else
                segment
              end
            end
            "/" + normalized.join("/")
          end
        end

        def start(_context)
          @transport = self.class.install!
          @requests = 0
          @by_path = Hash.new(0)
          @previous = Thread.current[ACTIVE_KEY]
          Thread.current[ACTIVE_KEY] = self
        end

        def stop(_context)
          Thread.current[ACTIVE_KEY] = @previous
          by_path = @by_path.sort_by { |name, count| [-count, name] }.to_h
          {"requests" => @requests, "by_path" => by_path, "transport" => @transport}
        end

        def record(method, path)
          @requests += 1
          @by_path["#{method.to_s.upcase} #{self.class.normalize_path(path)}"] += 1
        end
      end
    end
  end
end
