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
    @scribe = KitchenScribe::ScribeCopy.new
    @scribe.configure
  end

  describe "#run" do
    before(:each) do
      @scribe.stub(:remote_configured?)
      @scribe.stub(:pull)
      @scribe.stub(:fetch_configs)
      @scribe.stub(:commit)
      @scribe.stub(:push)
      @scribe.stub(:configure)
      @scribe.stub(:switch_branches)
      @scribe.stub(:fetch)
    end

    it "configures itself" do
      @scribe.should_receive(:configure)
      @scribe.run
    end

    it "switches the branch" do
      @scribe.should_receive(:switch_branches)
      @scribe.run
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

      it "doesn't attempt to fetch from the remote repository" do
        @scribe.should_not_receive(:fetch)
        @scribe.run
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

      it "fetches changes from remote repository" do
        @scribe.should_receive(:fetch)
        @scribe.run
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

  describe "#configure" do

    describe "when no configuration is given" do
      before(:each) do
        @scribe.config = {}
        Chef::Config[:knife][:scribe] = nil
      end

      it "uses the default values for all parameters" do
        @scribe.configure
        @scribe.config[:chronicle_path].should == KitchenScribe::ScribeCopy::DEFAULT_CHRONICLE_PATH
        @scribe.config[:remote_name].should == KitchenScribe::ScribeCopy::DEFAULT_REMOTE_NAME
        @scribe.config[:branch].should == KitchenScribe::ScribeCopy::DEFAULT_BRANCH
        @scribe.config[:commit_message].should == KitchenScribe::ScribeCopy::DEFAULT_COMMIT_MESSAGE
      end
    end

    describe "when configuration is given through knife config" do
      before(:each) do
        Chef::Config[:knife][:scribe] = {}
        Chef::Config[:knife][:scribe][:chronicle_path] = KitchenScribe::ScribeCopy::DEFAULT_CHRONICLE_PATH + "_knife"
        Chef::Config[:knife][:scribe][:remote_name] =  KitchenScribe::ScribeCopy::DEFAULT_REMOTE_NAME + "_knife"
        Chef::Config[:knife][:scribe][:branch] =  KitchenScribe::ScribeCopy::DEFAULT_BRANCH + "_knife"
        Chef::Config[:knife][:scribe][:commit_message] = KitchenScribe::ScribeCopy::DEFAULT_COMMIT_MESSAGE + "_knife"
        @scribe.config = {}
      end

      describe "when no other configuration is given" do
        before(:each) do
          @scribe.config = {}
        end

        it "uses the configuration from knife config" do
          @scribe.configure
          @scribe.config[:chronicle_path].should == Chef::Config[:knife][:scribe][:chronicle_path]
          @scribe.config[:remote_name].should == Chef::Config[:knife][:scribe][:remote_name]
          @scribe.config[:branch].should == Chef::Config[:knife][:scribe][:branch]
          @scribe.config[:commit_message].should == Chef::Config[:knife][:scribe][:commit_message]
        end
      end

      describe "when command line configuration is given" do
        before(:each) do
          @scribe.config[:chronicle_path] = KitchenScribe::ScribeCopy::DEFAULT_CHRONICLE_PATH + "_cmd"
          @scribe.config[:remote_name] =  KitchenScribe::ScribeCopy::DEFAULT_REMOTE_NAME + "_cmd"
          @scribe.config[:branch] =  KitchenScribe::ScribeCopy::DEFAULT_BRANCH + "_cmd"
          @scribe.config[:commit_message] = KitchenScribe::ScribeCopy::DEFAULT_COMMIT_MESSAGE + "_cmd"
        end

        it "uses the configuration from command line" do
          @scribe.configure
          @scribe.config[:chronicle_path].should == KitchenScribe::ScribeCopy::DEFAULT_CHRONICLE_PATH + "_cmd"
          @scribe.config[:remote_name].should == KitchenScribe::ScribeCopy::DEFAULT_REMOTE_NAME + "_cmd"
          @scribe.config[:branch].should == KitchenScribe::ScribeCopy::DEFAULT_BRANCH + "_cmd"
          @scribe.config[:commit_message].should == KitchenScribe::ScribeCopy::DEFAULT_COMMIT_MESSAGE + "_cmd"
        end
      end
    end
  end

  describe "#switch_branches" do

    before(:each) do
      @command_response = double('shell_out')
      @command_response.stub(:exitstatus) { 0 }
      @branch_command = "git branch"
    end

    describe "when already on the branch" do
      it "does nothing" do
        @command_response.stub(:stdout) { "#{@scribe.config[:branch]}2\n* #{@scribe.config[:branch]}\n#a{@scribe.config[:branch]}" }
        @scribe.should_receive(:shell_out!).with(@branch_command,
                                                 :cwd => @scribe.config[:chronicle_path]).and_return(@command_response)
        switch_command = "git checkout -B #{@scribe.config[:branch]}"
        @scribe.should_not_receive(:shell_out!).with(switch_command,
                                                     :cwd => @scribe.config[:chronicle_path])
        @scribe.switch_branches
      end
    end

    describe "when the branch exists but is not the current one" do
      it "switches to the branch" do
        @command_response.stub(:stdout) { "#{@scribe.config[:branch]}2\n  #{@scribe.config[:branch]}\n#*  a{@scribe.config[:branch]}" }
        @scribe.should_receive(:shell_out!).with(@branch_command,
                                                 :cwd => @scribe.config[:chronicle_path]).and_return(@command_response)
        switch_command = "git checkout -B #{@scribe.config[:branch]}"
        @scribe.should_receive(:shell_out!).with(switch_command,
                                                 :cwd => @scribe.config[:chronicle_path])
        @scribe.switch_branches
      end
    end

    describe "when the branch doesn't exist'" do
      it "creates the branch and switches to it" do
        @command_response.stub(:stdout) { "* #{@scribe.config[:branch]}2\n#a{@scribe.config[:branch]}" }
        @scribe.should_receive(:shell_out!).with(@branch_command,
                                                 :cwd => @scribe.config[:chronicle_path]).and_return(@command_response)
        switch_command = "git checkout -B #{@scribe.config[:branch]}"
        @scribe.should_receive(:shell_out!).with(switch_command,
                                                 :cwd => @scribe.config[:chronicle_path])
        @scribe.switch_branches
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
                                               :cwd => @scribe.config[:chronicle_path]).and_return(@command_response)
      @scribe.remote_configured?.should be(false)
    end


    it "returns false if a given remote is not configured" do
      @command_response.stub(:stdout) { "another_remote_name\nyet_another_remote_name\nAAA#{@scribe.config[:remote_name]}" }
      @scribe.should_receive(:shell_out!).with(@remote_command,
                                               :cwd => @scribe.config[:chronicle_path]).and_return(@command_response)

      @scribe.remote_configured?.should be(false)
    end

    it "returns true if a given remote is configured" do
      @command_response.stub(:stdout) { "another_#{@scribe.config[:remote_name]}\n#{@scribe.config[:remote_name]}\nyet_another_#{@scribe.config[:remote_name]}" }
      @scribe.should_receive(:shell_out!).with(@remote_command,
                                               :cwd => @scribe.config[:chronicle_path]).and_return(@command_response)
      @scribe.remote_configured?.should be(true)
    end
  end

  describe "#fetch" do
    it "fetches the changes from the remote repository" do
      fetch_command = "git fetch #{@scribe.config[:remote_name]}"
      @scribe.should_receive(:shell_out!).with(fetch_command,
                                               :cwd => @scribe.config[:chronicle_path])
      @scribe.fetch
    end
  end


  describe "#pull" do
    before(:each) do
      @command_response = double('shell_out')
      @command_response.stub(:exitstatus) { 0 }
    end

    describe "when a remote branch already exists" do
      it "pulls from the remote repository" do
        @command_response.stub(:stdout) { "#{@scribe.config[:branch]}\nremotes/#{@scribe.config[:remote_name]}/#{@scribe.config[:branch]}" }
        check_remote_branch_command = "git branch -a"
        @scribe.should_receive(:shell_out!).with(check_remote_branch_command,
                                                 :cwd => @scribe.config[:chronicle_path]).and_return(@command_response)
        pull_command = "git pull #{@scribe.config[:remote_name]} #{@scribe.config[:branch]}"
        @scribe.should_receive(:shell_out!).with(pull_command,
                                                 :cwd => @scribe.config[:chronicle_path])
        @scribe.pull
      end
    end

    describe "when a remote branch doesn't already exist" do
      it "doesn't pull'" do
        @command_response.stub(:stdout) { "#{@scribe.config[:branch]}2\nremotes/#{@scribe.config[:remote_name]}/#{@scribe.config[:branch]}2" }
        check_remote_branch_command = "git branch -a"
        @scribe.should_receive(:shell_out!).with(check_remote_branch_command,
                                                 :cwd => @scribe.config[:chronicle_path]).and_return(@command_response)
        pull_command = "git pull #{@scribe.config[:remote_name]} #{@scribe.config[:branch]}"
        @scribe.should_not_receive(:shell_out!).with(pull_command,
                                                 :cwd => @scribe.config[:chronicle_path])
        @scribe.pull
      end
    end

    describe "when the repository is empty" do
      it "doesn't pull'" do
        @command_response.stub(:stdout) { "" }
        check_remote_branch_command = "git branch -a"
        @scribe.should_receive(:shell_out!).with(check_remote_branch_command,
                                                 :cwd => @scribe.config[:chronicle_path]).and_return(@command_response)
        pull_command = "git pull #{@scribe.config[:remote_name]} #{@scribe.config[:branch]}"
        @scribe.should_not_receive(:shell_out!).with(pull_command,
                                                     :cwd => @scribe.config[:chronicle_path])
        @scribe.pull
      end

    end
  end

  describe "#commit" do
    before(:each) do
      @command_response = double('shell_out')
      @command_response.stub(:exitstatus) { 0 }
      @command_response.stub(:stdout) { "" }
      @scribe.config[:commit_message] = "Commit message at %TIME%"
    end

    it "adds all files prior to commit" do
      expected_command = "git add ."
      @scribe.should_receive(:shell_out!).with(expected_command,
                                               :cwd => @scribe.config[:chronicle_path]).and_return(@command_response)
      pull_command = "git pull remote_name branch_name"
      @scribe.stub(:shell_out!)
      @scribe.commit
    end

    it "commits all changes" do
      expected_command = "git commit -m \"#{@scribe.config[:commit_message].gsub(/%TIME%/, Time.now.to_s)}\""
      @scribe.stub(:shell_out!)
      @scribe.should_receive(:shell_out!).with(expected_command,
                                               :cwd => @scribe.config[:chronicle_path],
                                               :returns => [0, 1]).and_return(@command_response)
      @scribe.commit
    end
  end

  describe "#push" do
    it "pushes to the remote repository" do
      push_command = "git push #{@scribe.config[:remote_name]} #{@scribe.config[:branch]}"
      @scribe.should_receive(:shell_out!).with(push_command,
                                               :cwd => @scribe.config[:chronicle_path])
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
      Chef::Environment.stub(:list) { { @environment1.name => @environment1, @environment2.name => @environment2 } }
    end

    it "saves each env to a file" do
      @scribe.should_receive(:save_to_file).with("environments", @environment1.name, @environment1)
      @scribe.should_receive(:save_to_file).with("environments", @environment2.name, @environment2)
      @scribe.fetch_environments
    end
  end

  describe "#fetch_roles" do
    before(:each) do
      @role1 = { :test1 => :value1 }
      @role1.stub(:name) { "role_name1" }
      @role2 = { :test2 => :value2 }
      @role2.stub(:name) { "role_name2" }
      Chef::Role.stub(:list) { { @role1.name => @role1, @role2.name => @role2 } }
    end

    it "saves each role to a file" do
      @scribe.should_receive(:save_to_file).with("roles", @role1.name, @role1)
      @scribe.should_receive(:save_to_file).with("roles", @role2.name, @role2)
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
      Chef::Node.stub(:list) { { @node1.name => @node1, @node2.name => @node2 } }
    end

    it "saves each node to a file" do
      @scribe.should_receive(:save_to_file).with("nodes", @node1.name, @serialized_node1)
      @scribe.should_receive(:save_to_file).with("nodes", @node2.name, @serialized_node2)
      @scribe.fetch_nodes
    end
  end

  describe "#save_to_file" do
    before(:each) do
      @f1 = double()
      @f1.stub(:write)
      @data = { :test_key2 => "test_value2", :test_key2 => "test_value2"}
    end

    it "saves deeply sorted data into a specific file in a specific directory" do
      File.should_receive(:open).with(File.join(@scribe.config[:chronicle_path], "dir", "name.json"), "w").and_yield(@f1)
      @scribe.should_receive(:deep_sort).with(@data).and_return({:sorted => "data"})
      @f1.should_receive(:write).with(JSON.pretty_generate({:sorted => "data"}))
      @scribe.save_to_file "dir", "name", @data
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
