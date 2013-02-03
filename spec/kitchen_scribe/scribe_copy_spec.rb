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
                                               :cwd => "chronicle_path",
                                               :returns => [0, 1]).and_return(@command_response)
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
    before(:each) do
      @environment1 = { :test1 => :value1 }
      @environment1.stub(:name) { "env_name1" }
      @environment2 = { :test2 => :value2 }
      @environment2.stub(:name) { "env_name2" }
      environments = double()
      environments.stub(:list) { [@environment1, @environment2] }
      @scribe.stub(:environments) { environments }
      @f1 = double()
      @f1.stub(:write)
      @f2 = double()
      @f2.stub(:write)
    end

    it "saves the environments into separate files" do
      File.should_receive(:open).with(File.join(Chef::Config[:knife][:scribe][:chronicle_path], "environments", @environment1.name + ".json"), "w").and_yield(@f1)
      File.should_receive(:open).with(File.join(Chef::Config[:knife][:scribe][:chronicle_path], "environments", @environment2.name + ".json"), "w").and_yield(@f2)
      @f1.should_receive(:write).with(JSON.pretty_generate(@scribe.deep_sort(@environment1)))
      @f2.should_receive(:write).with(JSON.pretty_generate(@scribe.deep_sort(@environment2)))
      @scribe.fetch_environments
    end

    it "saves the roles as deeply sorted hashes" do
      File.should_receive(:open).with(File.join(Chef::Config[:knife][:scribe][:chronicle_path], "environments", @environment1.name + ".json"), "w").and_yield(@f1)
      File.should_receive(:open).with(File.join(Chef::Config[:knife][:scribe][:chronicle_path], "environments", @environment2.name + ".json"), "w").and_yield(@f2)
      @scribe.should_receive(:deep_sort).with(@environment1).and_return(@environment1)
      @scribe.should_receive(:deep_sort).with(@environment2).and_return(@environment2)
      @scribe.fetch_environments
    end
  end

  describe "#fetch_roles" do
    before(:each) do
      @role1 = { :test1 => :value1 }
      @role1.stub(:name) { "role_name1" }
      @role2 = { :test2 => :value2 }
      @role2.stub(:name) { "role_name2" }
      @roles = double()
      @roles.stub(:list) { [@role1, @role2] }
      @f1 = double()
      @f1.stub(:write)
      @f2 = double()
      @f2.stub(:write)
      @scribe.stub(:roles) { @roles }
    end

    it "saves the roles into separate files" do
      File.should_receive(:open).with(File.join(Chef::Config[:knife][:scribe][:chronicle_path], "roles", @role1.name + ".json"), "w").and_yield(@f1)
      File.should_receive(:open).with(File.join(Chef::Config[:knife][:scribe][:chronicle_path], "roles", @role2.name + ".json"), "w").and_yield(@f2)
      @f1.should_receive(:write).with(JSON.pretty_generate(@scribe.deep_sort(@role1)))
      @f2.should_receive(:write).with(JSON.pretty_generate(@scribe.deep_sort(@role2)))
      @scribe.fetch_roles
    end

    it "saves the roles as a deeply sorted hash" do
      File.should_receive(:open).with(File.join(Chef::Config[:knife][:scribe][:chronicle_path], "roles", @role1.name + ".json"), "w").and_yield(@f1)
      File.should_receive(:open).with(File.join(Chef::Config[:knife][:scribe][:chronicle_path], "roles", @role2.name + ".json"), "w").and_yield(@f2)
      @scribe.should_receive(:deep_sort).with(@role1).and_return(@role1)
      @scribe.should_receive(:deep_sort).with(@role2).and_return(@role2)
      @scribe.fetch_roles
    end
  end

  describe "#fetch_nodes" do
    before(:each) do
      @node1 = { :test1 => :value1 }
      @node1.stub(:name) { "node_name1" }
      @node1.stub(:chef_environment) { "chef_environment1" }
      @node1.stub(:normal_attrs) { { :attr1 => "val1" } }
      @node1.stub(:run_list) { ["cookbook1", "cookbook2"] }
      @serialized_node1 = {"name" => @node1.name, "env" => @node1.chef_environment, "attribiutes" => @node1.normal_attrs, "run_list" => @node1.run_list}
      @node2 = { :test2 => :value2 }
      @node2.stub(:name) { "node_name2" }
      @node2.stub(:chef_environment) { "chef_environment2" }
      @node2.stub(:normal_attrs) { { :attrA => "valA" } }
      @node2.stub(:run_list) { ["cookbookA", "cookbookB"] }
      @serialized_node2 = {"name" => @node2.name, "env" => @node2.chef_environment, "attribiutes" => @node2.normal_attrs, "run_list" => @node2.run_list}
      nodes = double()
      nodes.stub(:list) { [@node1, @node2] }
      @scribe.stub(:nodes) { nodes }
      @f1 = double()
      @f1.stub(:write)
      @f2 = double()
      @f2.stub(:write)
    end

    it "saves the nodes into separate files" do
      File.should_receive(:open).with(File.join(Chef::Config[:knife][:scribe][:chronicle_path], "nodes", @node1.name + ".json"), "w").and_yield(@f1)
      File.should_receive(:open).with(File.join(Chef::Config[:knife][:scribe][:chronicle_path], "nodes", @node2.name + ".json"), "w").and_yield(@f2)
      @f1.should_receive(:write).with(JSON.pretty_generate(@scribe.deep_sort(@serialized_node1)))
      @f2.should_receive(:write).with(JSON.pretty_generate(@scribe.deep_sort(@serialized_node2)))
      @scribe.fetch_nodes
    end

    it "saves the nodes into separate files" do
      File.should_receive(:open).with(File.join(Chef::Config[:knife][:scribe][:chronicle_path], "nodes", @node1.name + ".json"), "w").and_yield(@f1)
      File.should_receive(:open).with(File.join(Chef::Config[:knife][:scribe][:chronicle_path], "nodes", @node2.name + ".json"), "w").and_yield(@f2)
      @scribe.should_receive(:deep_sort).with(@serialized_node1).and_return(@serialized_node1)
      @scribe.should_receive(:deep_sort).with(@serialized_node2).and_return(@serialized_node1)
      @scribe.fetch_nodes
    end

  end

  describe "#deep_sort" do
    describe "when it gets a hash as a parameter" do
      it "sorts the hash" do
        sorted_hash = @scribe.deep_sort({:c => 3, :a => 1, :x => 0, :d => -2})
        sorted_values = [[:a, 1], [:c,3], [:d,-2], [:x,0]]
        i = 0
        sorted_hash.each do |key, value|
          key.should eql(sorted_values[i][0])
          value.should eql(sorted_values[i][1])
          i +=1
        end
      end

      it "calls itself recursively with each value" do
        hash_to_sort = {:g => 3, :b => 1, :z => 0, :h => -2}
        @scribe.should_receive(:deep_sort).with(hash_to_sort).and_call_original
        hash_to_sort.values.each {|value| @scribe.should_receive(:deep_sort).with(value)}
        @scribe.deep_sort(hash_to_sort)
      end

      it "returns a deep sorted hash" do
        hash_to_sort = {"zz" => { "z" => 0, "h" => -2}}
        @scribe.deep_sort(hash_to_sort).should eql({"zz" => { "h" => -2, "z" => 0}})
      end
    end

    describe "when it gets a simple array as a parameter" do
      it "doesn't sort the array" do
        array = [3, 1, 0, -2]
        sorted_hash = @scribe.deep_sort(array)
        sorted_hash.each_with_index do |value, index|
          value.should eql(array[index])
        end
      end

      it "calls itself recursively with each value" do
        array = [3, 1, 0, -2]
        @scribe.should_receive(:deep_sort).with(array).and_call_original
        array.each {|value| @scribe.should_receive(:deep_sort).with(value)}
        @scribe.deep_sort(array)
      end

      it "returns a deep sorted array" do
        hash_to_sort = [{ "u" => 0, "h" => -2 }, { "u" => "test", "d" => -100 }]
        @scribe.deep_sort(hash_to_sort).should eql([{ "h" => -2, "u" => 0 }, { "d" => -100, "u" => "test" }])
      end
    end

    describe "when it gets something that's not a hash or an array as a prameter" do
      it "returns the input param" do
        str = "test"
        @scribe.deep_sort(str).should equal(str)
        @scribe.deep_sort(1).should equal(1)
        @scribe.deep_sort(true).should equal(true)
        @scribe.deep_sort(nil).should eql(nil)
      end
    end
  end
end
