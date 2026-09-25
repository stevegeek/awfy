# frozen_string_literal: true

module Awfy
  # For each (group, report, test) under both labels, compares the latest :measure result of
  # each, per collector. Tests under one label only are listed as missing; collectors under one
  # label only are listed per test in "collectors_missing". "warnings" lists each environment
  # field (isolation, runtime, run meta) that differs between the two results.
  class Comparison < Literal::Object
    # Facts in the run meta that differ on every run and so say nothing about the environment.
    IGNORED_META_FIELDS = ["pid"].freeze

    prop :store, Stores::Base, reader: :private
    prop :baseline, String, reader: :private
    prop :against, String, reader: :private
    prop :group_names, _Nilable(_Array(String)), reader: :private

    def call
      base = latest(baseline)
      other = latest(against)
      results = []
      missing = []
      (base.keys | other.keys).sort.each do |key|
        if base[key] && other[key]
          results << compare_pair(key, base[key], other[key])
        else
          missing << {"group" => key[0], "report" => key[1], "test" => key[2], "only_in" => base[key] ? baseline : against}
        end
      end
      {"awfy" => VERSION, "baseline" => baseline, "against" => against, "results" => results, "missing" => missing}
    end

    private

    # group_names, when given, restricts both labels to those groups before the diff: a test in
    # a group outside the list must not appear as missing. A single-element list is the
    # single-group form.
    def latest(label)
      found = store.query_results(type: :measure, label:)
      found = found.select { |result| group_names.include?(result.group_name) } if group_names
      raise Errors::LabelNotFoundError.new(label) if found.empty?

      found.group_by { [it.group_name, it.report_name, it.test_name] }
        .transform_values { |results| results.max_by { it.timestamp.to_i } }
    end

    def compare_pair(key, base_result, other_result)
      base = base_result.result_data
      other = other_result.result_data
      base_collectors = base[:collectors] || {}
      other_collectors = other[:collectors] || {}
      collectors = (base_collectors.keys & other_collectors.keys).sort.to_h do |name|
        klass = Collectors.lookup(name) || Collector
        b = base_collectors[name]
        o = other_collectors[name]
        [name, {"metrics" => klass.compare(b, o), "extras" => klass.extras(b, o)}]
      end
      only_one = (base_collectors.keys | other_collectors.keys) - (base_collectors.keys & other_collectors.keys)
      collectors_missing = only_one.sort.to_h do |name|
        [name, base_collectors.key?(name) ? baseline : against]
      end
      {
        "group" => key[0], "report" => key[1], "test" => key[2],
        "isolation" => {"baseline" => base[:isolation], "against" => other[:isolation]},
        "outcome_differs" => base[:outcome] != other[:outcome],
        # False when neither label recorded an outcome (no awfy_outcome, no test.rb helper call):
        # distinct from both recording the same one, which outcome_differs alone cannot tell.
        "outcome_recorded" => !(base[:outcome].nil? && other[:outcome].nil?),
        "outcome" => {"baseline" => base[:outcome], "against" => other[:outcome]},
        "warnings" => warnings(base_result, other_result),
        "collectors" => collectors,
        "collectors_missing" => collectors_missing
      }
    end

    # Results saved before run meta was stored have no :meta; their meta fields are not compared.
    def warnings(base_result, other_result)
      base = base_result.result_data
      other = other_result.result_data
      fields = {
        "isolation" => [base[:isolation], other[:isolation]],
        "runtime" => [base_result.runtime.value, other_result.runtime.value]
      }
      if base[:meta] && other[:meta]
        (base[:meta].keys | other[:meta].keys).map(&:to_s).sort.each do |name|
          next if IGNORED_META_FIELDS.include?(name)

          fields[name] = [base[:meta][name], other[:meta][name]]
        end
      end
      fields.filter_map do |field, (b, o)|
        {"field" => field, "baseline" => b, "against" => o} unless b == o
      end
    end
  end
end
