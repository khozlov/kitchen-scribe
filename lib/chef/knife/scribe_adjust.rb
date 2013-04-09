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

class Chef
  class Knife
    class ScribeAdjust < Chef::Knife

      include Chef::Mixin::DeepMerge

      TEMPLATE_HASH = { "author_name" => "",
        "author_email" => "",
        "description" => "",
        "action" => "merge",
        "type" => "environment",
        "search" => "",
        "adjustment" => { "default_attributes" => { },
          "override_attributes" => { }
        }
      }

      banner "knife scribe adjust FILE [FILE..]"

      deps do
        require 'chef/environment'
      end

      option :generate,
      :short => "-g",
      :long  => "--generate",
      :description => "generate adjustment templates"

      alias_method :action_merge, :merge

      def run
        if @name_args[0].nil?
          show_usage
          ui.fatal("You must specify an adjustment file")
          exit 1
        end
        @name_args.each do |filename|
          if config[:generate] == true
            generate_template(filename)
          else
            apply_adjustment(filename)
          end
        end
      end

      def generate_template(filename)
        File.open(filename, "w") { |file| file.write(JSON.pretty_generate(TEMPLATE_HASH)) }
      end

      def apply_adjustment(filename)
        adjustment_hash = File.open(filename, "r") { |file| JSON.load(file) }
        return ui.fatal("Adjustment must be a JSON hash") unless adjustment_hash.kind_of?(Hash)
        ["action", "type", "search", "adjustment"].each do |required_key|
          return ui.fatal("Adjustment hash must contain " + required_key) unless adjustment_hash.has_key?(required_key)
        end
        return ui.fatal("Incorrect action") unless respond_to?(adjustment_hash["action"])
        query = adjustment_hash["search"].include?(":") ? adjustment_hash["search"] : "name:" + adjustment_hash["search"]
        Chef::Search::Query.new.search(adjustment_hash["type"], query ) do |result|
          result.class.json_create(send(("action_" + adjustment_hash["action"]).to_sym, result.to_hash, adjustment_hash["adjustment"])).save
        end
      end
    end
  end
end
