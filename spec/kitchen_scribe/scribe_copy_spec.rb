require File.expand_path('../../spec_helper', __FILE__)

describe KitchenScribe::ScribeCopy do
  before(:each) do
    Chef::Config[:knife][:scribe] = {}
    Chef::Config[:knife][:scribe][:chronicle_path] = "chronicle_path"
    Chef::Config[:knife][:scribe][:remote_name] =  "remote_name"
    Chef::Config[:knife][:scribe][:branch] =  "branch_name"
    @scribe = KitchenScribe::ScribeCopy.new
  end

  describe "#run" do
    before(:each) do
      @scribe.stub(:remote_configured?)
      @scribe.stub(:pull)
      @scribe.stub(:fetch_configs)
      @scribe.stub(:commit)
      @scribe.stub(:push)
    end

    it "checks if a given remote is configured" do
      @scribe.should_receive(:remote_configured?)
      @scribe.run
    end

    it "fetches the configs from the chef server" do
      @scribe.should_receive(:fetch_configs)
      @scribe.run
    end

    it "commits the changes" do
      @scribe.should_receive(:commit)
      @scribe.run
    end

    describe "when the remote is not configured" do
      before(:each) do
        @scribe.stub(:remote_configured?) { false }
      end

      it "doesn't attempt to pull the changes from the remote repository" do
        @scribe.should_not_receive(:pull)
        @scribe.run
      end

      it "doesn't attempt to push the changes to the remote repository" do
        @scribe.should_not_receive(:push)
        @scribe.run
      end

    end

    describe "when the remote is configured" do
      before(:each) do
        @scribe.stub(:remote_configured?) { true }
      end

      it "pulls changes from remote repository" do
        @scribe.should_receive(:pull)
        @scribe.run
      end

      it "pushes the changes to the remote repository" do
        @scribe.should_receive(:push)
        @scribe.run
      end
    end
  end

  describe "#remote_configured?" do

    before(:each) do
      @command_response = double('shell_out')
      @command_response.stub(:exitstatus) { 0 }
      @remote_command = "git remote"
    end

    it "returns false if no remote is configured" do
      @command_response.stub(:stdout) { "" }
      @scribe.should_receive(:shell_out!).with(@remote_command,
                                               :cwd => "chronicle_path").and_return(@command_response)
      @scribe.remote_configured?.should be(false)
    end


    it "returns false if a given remote is not configured" do
      @command_response.stub(:stdout) { "another_remote_name\nyet_another_remote_name" }
      @scribe.should_receive(:shell_out!).with(@remote_command,
                                               :cwd => "chronicle_path").and_return(@command_response)

      @scribe.remote_configured?.should be(false)
    end

    it "returns true if a given remote is configured" do
      @command_response.stub(:stdout) { "another_remote_name\nremote_name\nyet_another_remote_name" }
      @scribe.should_receive(:shell_out!).with(@remote_command,
                                               :cwd => "chronicle_path").and_return(@command_response)
      @scribe.remote_configured?.should be(true)
    end
  end

  describe "#pull" do
    it "pulls from the remote repository" do
      pull_command = "git pull #{Chef::Config[:knife][:scribe][:remote_name]} #{Chef::Config[:knife][:scribe][:branch]}"
      @scribe.should_receive(:shell_out!).with(pull_command,
                                               :cwd => "chronicle_path")
      @scribe.pull
    end
  end

  describe "#commit" do
    before(:each) do
      @command_response = double('shell_out')
      @command_response.stub(:exitstatus) { 0 }
      @command_response.stub(:stdout) { "" }
      @scribe.config[:message] = "Commit message"
    end

    it "adds all files prior to commit" do
      expected_command = "git add ."
      @scribe.should_receive(:shell_out!).with(expected_command,
                                               :cwd => "chronicle_path").and_return(@command_response)
      pull_command = "git pull remote_name branch_name"
      @scribe.stub(:shell_out!)
      @scribe.commit
    end

    it "commits all changes" do
      expected_command = "git commit -m \"#{@scribe.config[:message]}\""
      @scribe.stub(:shell_out!)
      @scribe.should_receive(:shell_out!).with(expected_command,
                                               :cwd => "chronicle_path").and_return(@command_response)
      @scribe.commit
    end
  end

  describe "#push" do
    it "pushes to the remote repository" do
      push_command = "git push #{Chef::Config[:knife][:scribe][:remote_name]} #{Chef::Config[:knife][:scribe][:branch]}"
      @scribe.should_receive(:shell_out!).with(push_command,
                                               :cwd => "chronicle_path")
      @scribe.push
    end
  end

  describe "#fetch_configs" do
    before(:each) do
      @scribe.stub(:fetch_environments)
      @scribe.stub(:fetch_roles)
      @scribe.stub(:fetch_nodes)
    end

    it "fetches environment configs" do
      @scribe.should_receive(:fetch_environments)
      @scribe.fetch_configs
    end

    it "fetches roles configs" do
      @scribe.should_receive(:fetch_roles)
      @scribe.fetch_configs
    end

    it "fetches nodes configs" do
      @scribe.should_receive(:fetch_nodes)
      @scribe.fetch_configs
    end
  end

  describe "#fetch_environments" do
    it "saves the environments into separate files" do
      environment1 = { :test1 => :value1 }
      environment1.stub(:name) { "env_name1" }
      environment2 = { :test2 => :value2 }
      environment2.stub(:name) { "env_name2" }
      environments = double()
      environments.stub(:list) { [environment1, environment2] }
      @scribe.stub(:environments) { environments }
      f1 = double()
      f1.stub(:write)
      f2 = double()
      f2.stub(:write)
      File.should_receive(:open).with(File.join(Chef::Config[:knife][:scribe][:chronicle_path], "environments", environment1.name), "w").and_yield(f1)
      File.should_receive(:open).with(File.join(Chef::Config[:knife][:scribe][:chronicle_path], "environments", environment2.name), "w").and_yield(f2)
      f1.should_receive(:write).with(JSON.pretty_generate(environment1))
      f2.should_receive(:write).with(JSON.pretty_generate(environment2))
      @scribe.fetch_environments
    end
  end

  describe "#fetch_roles" do
    it "saves the roles into separate files" do
      role1 = { :test1 => :value1 }
      role1.stub(:name) { "role_name1" }
      role2 = { :test2 => :value2 }
      role2.stub(:name) { "role_name2" }
      roles = double()
      roles.stub(:list) { [role1, role2] }
      @scribe.stub(:roles) { roles }
      f1 = double()
      f1.stub(:write)
      f2 = double()
      f2.stub(:write)
      File.should_receive(:open).with(File.join(Chef::Config[:knife][:scribe][:chronicle_path], "roles", role1.name), "w").and_yield(f1)
      File.should_receive(:open).with(File.join(Chef::Config[:knife][:scribe][:chronicle_path], "roles", role2.name), "w").and_yield(f2)
      f1.should_receive(:write).with(JSON.pretty_generate(role1))
      f2.should_receive(:write).with(JSON.pretty_generate(role2))
      @scribe.fetch_roles
    end
  end

  describe "#fetch_nodes" do
    it "saves the nodes into separate files" do
      node1 = { :test1 => :value1 }
      node1.stub(:name) { "node_name1" }
      node1.stub(:chef_environment) { "chef_environment1" }
      node1.stub(:normal_attrs) { { :attr1 => "val1" } }
      node1.stub(:run_list) { ["cookbook1", "cookbook2"] }
      serialized_node1 = {"name" => node1.name, "env" => node1.chef_environment, "attribiutes" => node1.normal_attrs, "run_list" => node1.run_list}
      node2 = { :test2 => :value2 }
      node2.stub(:name) { "node_name2" }
      node2.stub(:chef_environment) { "chef_environment2" }
      node2.stub(:normal_attrs) { { :attrA => "valA" } }
      node2.stub(:run_list) { ["cookbookA", "cookbookB"] }
      serialized_node2 = {"name" => node2.name, "env" => node2.chef_environment, "attribiutes" => node2.normal_attrs, "run_list" => node2.run_list}
      nodes = double()
      nodes.stub(:list) { [node1, node2] }
      @scribe.stub(:nodes) { nodes }
      f1 = double()
      f1.stub(:write)
      f2 = double()
      f2.stub(:write)
      File.should_receive(:open).with(File.join(Chef::Config[:knife][:scribe][:chronicle_path], "nodes", node1.name), "w").and_yield(f1)
      File.should_receive(:open).with(File.join(Chef::Config[:knife][:scribe][:chronicle_path], "nodes", node2.name), "w").and_yield(f2)
      f1.should_receive(:write).with(JSON.pretty_generate(serialized_node1))
      f2.should_receive(:write).with(JSON.pretty_generate(serialized_node2))
      @scribe.fetch_nodes
    end
  end
end
