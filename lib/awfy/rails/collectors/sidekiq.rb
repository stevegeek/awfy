# frozen_string_literal: true

module Awfy
  module Rails
    module Collectors
      # Queue and scheduled-set sizes before and after the call. The enqueued summary
      # is the outcome of perform_job.
      class Sidekiq < Awfy::Collector
        class Api
          def initialize
            require "sidekiq/api"
          end

          def queues = ::Sidekiq::Queue.all.to_h { |queue| [queue.name, queue.map(&:display_class)] }

          def scheduled_size = ::Sidekiq::ScheduledSet.new.size
        end

        class << self
          attr_writer :api

          def api
            @api ||= Api.new
          end

          def key = "sidekiq"

          def metrics(data) = {"total" => data["total"], "scheduled" => data["scheduled"]}.merge(data.fetch("by_class", {}))

          def outcome(data) = data&.slice("total", "by_class", "by_queue", "scheduled")
        end

        def start(_context)
          @before = snapshot
        end

        def stop(_context)
          after = snapshot
          by_queue = positive(after[:by_queue].to_h { |name, size| [name, size - @before[:by_queue].fetch(name, 0)] })
          by_class = positive(after[:by_class].to_h { |name, count| [name, count - @before[:by_class].fetch(name, 0)] })
          {"total" => by_queue.values.sum, "by_class" => by_class, "by_queue" => by_queue,
           "scheduled" => [after[:scheduled] - @before[:scheduled], 0].max}
        end

        private

        def snapshot
          queues = self.class.api.queues
          {by_queue: queues.transform_values(&:size), by_class: queues.values.flatten.tally, scheduled: self.class.api.scheduled_size}
        end

        def positive(hash) = hash.select { |_, count| count.positive? }.sort_by { |_, count| -count }.to_h
      end
    end
  end
end
