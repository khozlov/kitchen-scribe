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
      shell_out!("git commit -m \"#{config[:message]}\"", { :cwd => Chef::Config[:knife][:scribe][:chronicle_path] })
    end

    def push
      push_command = "git push #{Chef::Config[:knife][:scribe][:remote_name]} #{Chef::Config[:knife][:scribe][:branch]}"
      shell_out!(push_command, { :cwd => Chef::Config[:knife][:scribe][:chronicle_path] })
    end
1
    def fetch_configs
      fetch_environments
      fetch_nodes
      fetch_roles
    end

    def fetch_environments
      environments.list.each do |env|
        # TODO: Make sure environments are always serialized in the same way in terms of property order (I suspect they're not)
        File.open(File.join(Chef::Config[:knife][:scribe][:chronicle_path], "environments", env.name), "w") { |file| file.write(JSON.pretty_generate(env)) }
      end
    end

    def fetch_nodes
      nodes.list.each do |n|
        # TODO: Make sure nodes are always serialized in the same way in terms of property order (I suspect they're not)
        File.open(File.join(Chef::Config[:knife][:scribe][:chronicle_path], "nodes", n.name), "w") { |file| file.write(JSON.pretty_generate({"name" => n.name, "env" => n.chef_environment, "attribiutes" => n.normal_attrs, "run_list" => n.run_list})) }
      end
    end

    def fetch_roles
      roles.list.each do |r|
        # TODO: Make sure nodes are always serialized in the same way in terms of property order (I suspect they're not)
        File.open(File.join(Chef::Config[:knife][:scribe][:chronicle_path], "roles", r.name), "w") { |file| file.write(JSON.pretty_generate(r)) }
      end
    end
  end
end
