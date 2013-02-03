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
  class ScribeHire < Chef::Knife

    include Chef::Mixin::ShellOut

    banner "knife scribe hire"

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

    option :remote_url,
    :short => "-r REMOTE_URL",
    :long => "--remote-url REMOTE_URL",
    :description => "Url of the remote chronicle repository",
    :proc => Proc.new { |key|
      Chef::Config[:knife][:scribe] = {} if Chef::Config[:knife][:scribe].nil?
      Chef::Config[:knife][:scribe][:remote_url] = key
    }

    def run
      Shef::Extensions.extend_context_object(self)

      chronicle_path = (Chef::Config[:knife][:scribe] && Chef::Config[:knife][:scribe][:chronicle_path]) || File.join(Dir.pwd, ".chronicle")
      Dir.mkdir(chronicle_path) unless File.directory?(chronicle_path)
      init_chronicle(chronicle_path)
      setup_remote(chronicle_path)
      Dir.mkdir(File.join(chronicle_path, "environments")) unless File.directory?(File.join(chronicle_path, "environments"))
      Dir.mkdir(File.join(chronicle_path, "nodes")) unless File.directory?(File.join(chronicle_path, "nodes"))
      Dir.mkdir(File.join(chronicle_path, "roles")) unless File.directory?(File.join(chronicle_path, "roles"))
    end

    def init_chronicle(chronicle_path)
      shell_out!("git init", { :cwd => chronicle_path })
    end

    def setup_remote(chronicle_path)
      if remote_url = Chef::Config[:knife][:scribe] && Chef::Config[:knife][:scribe][:remote_url]
        remote_name = Chef::Config[:knife][:scribe][:remote_name] || "origin"
        check_remote_command = "git config --get remote.#{remote_name}.url"
        remote_status = shell_out!(check_remote_command, { :cwd => chronicle_path, :returns => [0,1,2] })
        case remote_status.exitstatus
        when 0, 2
          # In theory 2 should not happen unless somebody messed with
          # the checkout manually, but using --replace-all option will fix it
          unless remote_status.exitstatus != 2 && remote_status.stdout.strip.eql?(remote_url)
            update_remote_url_command = "git config --replace-all remote.#{remote_name}.url #{remote_url}"
            shell_out!(update_remote_url_command, { :cwd => chronicle_path })
          end
        when 1
          add_remote_command = "git remote add #{remote_name} #{remote_url}"
          shell_out!(add_remote_command, { :cwd => chronicle_path })
        end
      end
    end
  end
end
