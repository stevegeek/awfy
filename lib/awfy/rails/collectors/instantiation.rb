# frozen_string_literal: true

module Awfy
  module Rails
    module Collectors
      class Instantiation < Awfy::Collector
        def self.key = "instantiation"

        # Total plus one metric per class, so compare gives per-class deltas.
        def self.metrics(data) = {"total" => data["total"]}.merge(data.fetch("by_class", {}))

        def start(_context)
          @by_class = Hash.new(0)
          @subscriber = ::ActiveSupport::Notifications.subscribe("instantiation.active_record") do |event|
            @by_class[event.payload[:class_name]] += event.payload[:record_count]
          end
        end

        def stop(_context)
          ::ActiveSupport::Notifications.unsubscribe(@subscriber) if @subscriber
          @subscriber = nil
          {"total" => @by_class.values.sum, "by_class" => @by_class.sort_by { |_, count| -count }.to_h}
        end
      end
    end
  end
end
