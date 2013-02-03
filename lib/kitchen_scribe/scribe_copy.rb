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

require 'chef/mixin/shell_out'

module KitchenScribe
  class ScribeCopy < Chef::Knife

    include Chef::Mixin::ShellOut

    banner "knife scribe copy"

    deps do
      require 'chef/shef/ext'
    end

    option :chronicle_path,
    :short => "-p PATH",
    :long => "--chronicle-path PATH",
    :description => "Path to the directory where the chronicle should be located",
    :proc => Proc.new { |key|
      Chef::Config[:knife][:scribe] = {} if Chef::Config[:knife][:scribe].nil?
      Chef::Config[:knife][:scribe][:chronicle_path] = key
    }

    option :remote_name,
    :long => "--remote-name REMOTE_NAME",
    :description => "Name of the remote chronicle repository",
    :proc => Proc.new { |key|
      Chef::Config[:knife][:scribe] = {} if Chef::Config[:knife][:scribe].nil?
      Chef::Config[:knife][:scribe][:remote_name] = key
    }

    option :branch,
    :long => "--branch BRANCH_NAME",
    :description => "Name of the branch you want to use",
    :proc => Proc.new { |key|
      Chef::Config[:knife][:scribe] = {} if Chef::Config[:knife][:scribe].nil?
      Chef::Config[:knife][:scribe][:branch] = key
    }


    option :message,
    :short => "-m COMMIT_MESSAGE",
    :long => "--message COMMIT_MESSAGE",
    :description => "Message that should be used for the commit",
    :default => nil

    option :skip_commit,
    :long => "--skip-commit",
    :description => "Tell the scribe not to commit the copy",
    :boolean => true


    def run
      Shef::Extensions.extend_context_object(self)
      Chef::Config[:knife][:scribe] = {} if Chef::Config[:knife][:scribe].nil?
      Chef::Config[:knife][:scribe][:chronicle_path] ||= ".chronicle"
      Chef::Config[:knife][:scribe][:remote_name] ||=  "origin"
      Chef::Config[:knife][:scribe][:branch] ||=  "master"
      config[:message] ||= 'Commiting chef state as of ' + Time.now.to_s
      # I'm not doing any conflict or uncommited changes detection as chronicle should not be modified manualy
      # TODO: Add the ability to switch branches automatically
      pull if remote_configured?
      fetch_configs
      commit
      push if remote_configured?
    end

    def remote_configured?
      return @remote_configured unless @remote_configured.nil?
      remote_command = shell_out!("git remote", { :cwd => Chef::Config[:knife][:scribe][:chronicle_path] })
      return @remote_configured = !remote_command.stdout.empty? && remote_command.stdout.split("\n").collect {|r| r.strip}.include?(Chef::Config[:knife][:scribe][:remote_name])
    end

    def pull
      pull_command = "git pull #{Chef::Config[:knife][:scribe][:remote_name]} #{Chef::Config[:knife][:scribe][:branch]}"
      shell_out!(pull_command, { :cwd => Chef::Config[:knife][:scribe][:chronicle_path] })
    end

    def commit
      shell_out!("git add .", { :cwd => Chef::Config[:knife][:scribe][:chronicle_path] })
      shell_out!("git commit -m \"#{config[:message]}\"", { :cwd => Chef::Config[:knife][:scribe][:chronicle_path], :returns => [0, 1]})
    end

    def push
      push_command = "git push #{Chef::Config[:knife][:scribe][:remote_name]} #{Chef::Config[:knife][:scribe][:branch]}"
      shell_out!(push_command, { :cwd => Chef::Config[:knife][:scribe][:chronicle_path] })
    end

    def fetch_configs
      fetch_environments
      fetch_nodes
      fetch_roles
    end

    def fetch_environments
      environments.list.each do |env|
        File.open(File.join(Chef::Config[:knife][:scribe][:chronicle_path], "environments", env.name + ".json"), "w") { |file| file.write(JSON.pretty_generate(deep_sort(env.to_hash))) }
      end
    end

    def fetch_nodes
      nodes.list.each do |n|
        # TODO: Make sure nodes are always serialized in the same way in terms of property order (I suspect they're not)
        File.open(File.join(Chef::Config[:knife][:scribe][:chronicle_path], "nodes", n.name + ".json"), "w") { |file| file.write(JSON.pretty_generate(deep_sort({"name" => n.name, "env" => n.chef_environment, "attribiutes" => n.normal_attrs, "run_list" => n.run_list}))) }
      end
    end

    def fetch_roles
      roles.list.each do |r|
        File.open(File.join(Chef::Config[:knife][:scribe][:chronicle_path], "roles", r.name + ".json"), "w") { |file| file.write(JSON.pretty_generate(deep_sort(r.to_hash))) }
      end
    end

    def deep_sort param
      if param.is_a?(Hash)
        deeply_sorted_hash = {}
        param.keys.sort.each { |key| deeply_sorted_hash[key] = deep_sort(param[key]) }
        return deeply_sorted_hash
      elsif param.is_a?(Array)
        deeply_sorted_array = []
        param.each { |value| deeply_sorted_array.push(deep_sort(value)) }
        return deeply_sorted_array
      else
        return param
      end
    end
  end
end
