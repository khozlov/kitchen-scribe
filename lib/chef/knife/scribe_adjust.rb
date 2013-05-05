#
# Author:: Pawel Kozlowski (<pawel.kozlowski@u2i.com>)
# Copyright:: Copyright (c) 2013 Pawel Kozlowski
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/mixin/deep_merge'
require 'chef/mixin/shell_out'

class Chef
  class Knife
    class ScribeAdjust < Chef::Knife

      include Chef::Mixin::DeepMerge
      include Chef::Mixin::ShellOut

      deps do
        require_relative 'scribe_hire'
        require_relative 'scribe_copy'
      end

      TEMPLATE_HASH = { "author_name" => "",
        "author_email" => "",
        "description" => "",
        "adjustments" => []
      }

      ENVIRONMENT_ADJUSTMENT_TEMPLATE = {
        "adjustment" => { "default_attributes" => { },
          "override_attributes" => { },
          "cookbook_versions" => { }
        }
      }

      ROLE_ADJUSTMENT_TEMPLATE = {
        "adjustment" => { "default_attributes" => { },
          "override_attributes" => { },
          "run_list" => [ ]
        }
      }

      NODE_ADJUSTMENT_TEMPLATE = {
        "adjustment" => { "attributes" => { },
          "run_list" => [ ]
        }
      }

      banner "knife scribe adjust FILE [FILE..]"

      option :generate,
      :short => "-g",
      :long  => "--generate",
      :description => "generate adjustment templates"

      option :document,
      :short => "-d",
      :long  => "--document",
      :description => "document with copy copy"

      option :dryrun,
      :long  => "--dryrun",
      :description => "do a test run"


      option :type,
      :short => "-t TYPE",
      :long  => "--type TYPE",
      :description => "generate adjustment templates [environemnt|node|role]",
      :default => "environment"


      option :chronicle_path,
      :short => "-p PATH",
      :long => "--chronicle-path PATH",
      :description => "Path to the directory where the chronicle should be located",
      :default => nil

      option :remote_name,
      :long => "--remote-name REMOTE_NAME",
      :description => "Name of the remote chronicle repository",
      :default => nil

      option :remote_url,
      :short => "-r REMOTE_URL",
      :long => "--remote-url REMOTE_URL",
      :description => "Url of the remote chronicle repository",
      :default => nil

      option :branch,
      :long => "--branch BRANCH_NAME",
      :description => "Name of the branch you want to use",
      :default => nil


      alias_method :action_merge, :merge
      alias_method :action_hash_only_merge, :hash_only_merge

      def changes
        @changes ||= {}
      end

      def descriptions
        @descriptions ||= []
      end

      def errors
        @errors ||= []
      end


      def run
        if @name_args[0].nil?
          show_usage
          ui.fatal("At least one adjustment file needs to be specified!")
          exit 1
        end
        if config[:generate] == true
          @name_args.each { |filename| generate_template(filename) }
        else
          parse_adjustments
        end
      end

      def generate_templates

      end

      def parse_adjustments
        @name_args.each do |filename|
          errors.push({ "name" => filename, "general" => nil, "adjustments" => {} })
          parse_adjustment_file(filename)
        end
        if errors?
          print_errors
          exit 1 unless config[:dryrun]
        end
        if config[:dryrun]
          diff
        else
          if config[:document] == true
            hire
            record_state
          end
          write_adjustments
          record_state(descriptions.join("\n").strip) if config[:document] == true
        end
      end

      def generate_template(filename)
        unless ["environment", "role", "node"].include?(config[:type])
          ui.fatal("Incorrect adjustment type! Only 'node', 'environment' or 'role' allowed.")
          exit 1
        end
        TEMPLATE_HASH["adjustments"] = [self.class.class_eval(config[:type].upcase + "_ADJUSTMENT_TEMPLATE")]
        File.open(filename, "w") { |file| file.write(JSON.pretty_generate(TEMPLATE_HASH)) }
      end

      def parse_adjustment_file(filename)
        if !File.exists?(filename)
          errors.last["general"] = "File does not exist!"
        else
          begin
            adjustment_file = File.open(filename, "r") { |file| JSON.load(file) }
            if adjustment_file_valid? adjustment_file
              adjustment_file["adjustments"].each_with_index do |adjustment, index|
                apply_adjustment(adjustment) if adjustment_valid?(adjustment, index)
              end
            end
            if adjustment_file["adjustments"].length > errors.last["adjustments"].length
              description = adjustment_file["description"]
              description += "[with errors]" if errors.last["adjustments"].size > 0
              descriptions.push(description)
            end
          rescue JSON::ParserError
            errors.last["general"] = "Malformed JSON!"
          end
        end
      end

      def apply_adjustment(adjustment)
        query = adjustment["search"].include?(":") ? adjustment["search"] : "name:" + adjustment["search"]
        Chef::Search::Query.new.search(adjustment["type"], query ) do |result|
          result_hash = result.to_hash
          key = result_hash["chef_type"] + ":" + result_hash["name"]
          if changes.has_key? key
            result_hash = changes[key]["adjusted"]
          else
            changes.store(key, { "original" => result_hash })
          end
          changes[key].store("adjusted", send(("action_" + adjustment["action"]).to_sym, result_hash, adjustment["adjustment"]))
        end
      end

      def write_adjustments
        changes.values.each do |change|
          Chef.const_get(change["adjusted"]["chef_type"].capitalize).json_create(change["adjusted"]).save
        end
      end

      def adjustment_file_valid? adjustment_file
        unless adjustment_file.kind_of?(Hash)
          errors.last["general"] = "Adjustment file must contain a JSON hash!"
          return false
        end

        unless adjustment_file["adjustments"].kind_of?(Array)
          errors.last["general"] = "Adjustment file must contain an array of adjustments!"
          return false
        end
        true
      end

      def adjustment_valid?(adjustment, index)
        unless adjustment.kind_of?(Hash)
          errors.last["adjustments"].store(index,"Adjustment must be a JSON hash!")
          return false
        end

        ["action", "type", "search", "adjustment"].each do |required_key|
          unless adjustment.has_key?(required_key)
            errors.last["adjustments"].store(index, "Adjustment hash must contain " + required_key + "!")
            return false
          end
        end

        unless respond_to?("action_" + adjustment["action"])
          errors.last["adjustments"].store(index, "Incorrect action!")
          return false
        end
        true
      end

      def hire
        hired_scribe = Chef::Knife::ScribeHire.new
        [:chronicle_path, :remote_url, :remote_name].each { |key| hired_scribe.config[key] = config[key] }
        hired_scribe.run
      end

      def record_state(message = nil)
        if @copyist.nil?
          @copyist = Chef::Knife::ScribeCopy.new
          [:chronicle_path, :remote_name, :branch].each { |key| @copyist.config[key] = config[key] }
        end
        @copyist.config[:message] = message
        @copyist.run
      end

      def errors?
        errors.each { |err| return true if !err["general"].nil? || (err["adjustments"].size > 0) }
        false
      end

      def print_errors
        ui.error("ERRORS OCCURED:")
        errors.each do |err|
          ui.error(err["name"]) if !err["general"].nil? || (err["adjustments"].size > 0)
          ui.error("\t" + err["general"]) if !err["general"].nil?
          err["adjustments"].each { |num, adj_err| ui.error("\t[Adjustment #{num}]: #{adj_err}") }
        end
      end

      def action_overwrite(base, overwrite_with)
        if base.kind_of?(Hash) && overwrite_with.kind_of?(Hash)
          base.merge(overwrite_with)
        elsif overwrite_with.nil?
          base
        else
          overwrite_with
        end
      end
    end

    def deep_delete(delete_from, delete_spec)
      deep_delete!(delete_from.dup, delete_spec.dup)
    end

    alias_method :action_delete, :deep_delete

    def deep_delete!(delete_from, delete_spec)
      if delete_from.kind_of?(Hash) || delete_from.kind_of?(Array)
        if delete_spec.kind_of?(Array)
          delete_spec.each { |item| deep_delete!(delete_from, item) }
        elsif delete_spec.kind_of?(Hash)
          delete_spec.each { |key,item| deep_delete!(delete_from[key], item) }
        else
          delete_from.kind_of?(Array) ? delete_from.delete_at(delete_spec) : delete_from.delete(delete_spec)
        end
      end
      delete_from
    end

    def diff
      original_file = Tempfile.new("original")
      adjusted_file = Tempfile.new("adjusted")
      begin
        changes.each do |key, change|
          ui.info("[#{key}]")
          original_file.write(JSON.pretty_generate(change["original"]))
          adjusted_file.write(JSON.pretty_generate(change["adjusted"]))
          original_file.rewind
          adjusted_file.rewind
          diff_output = shell_out("diff -L original -L adjusted -u #{original_file.path} #{adjusted_file.path}")
          ui.info(diff_output.stdout)
        end
      ensure
        original_file.close
        original_file.unlink
        adjusted_file.close
        adjusted_file.unlink
      end
    end
  end
end
