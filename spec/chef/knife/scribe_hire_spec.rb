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

require File.expand_path('../../../spec_helper', __FILE__)

describe Chef::Knife::ScribeHire do
  before(:each) do
    Dir.stub(:mkdir)
    Dir.stub(:pwd) { "some_path" }
    @scribe = Chef::Knife::ScribeHire.new
    Chef::Config[:knife][:scribe] = {}
    @scribe.configure
  end

  describe "#run" do
    before(:each) do
      @scribe.stub(:setup_remote)
      @scribe.stub(:init_chronicle)
      File.stub(:directory?) { false }
    end

    it "calls #configure" do
      @scribe.should_receive(:configure)
      @scribe.run
    end

    it "creates the main chronicle directory in the chronicle path" do
      Dir.should_receive(:mkdir).with(@scribe.config[:chronicle_path])
      @scribe.run
    end

    it "creates the environments subdirectory in the chronicle path" do
      Dir.should_receive(:mkdir).with(File.join(@scribe.config[:chronicle_path], "environments"))
      @scribe.run
    end

    it "creates the nodes subdirectory in the chronicle path" do
      Dir.should_receive(:mkdir).with(File.join(@scribe.config[:chronicle_path], "nodes"))
      @scribe.run
    end

    it "creates the roles subdirectory in the chronicle path" do
      Dir.should_receive(:mkdir).with(File.join(@scribe.config[:chronicle_path], "roles"))
      @scribe.run
    end

    it "calls #init_chronicle" do
      @scribe.should_receive(:init_chronicle)
      @scribe.run
    end

    describe "when remote url was not specified" do
      it "doesn't call #setup_remote" do
        @scribe.should_not_receive(:setup_remote)
        @scribe.run
      end
    end

    describe "when remote url was specified" do
      before(:each) do
        @scribe.config[:remote_url] = "some_url"
      end
      it "calls #setup_remote" do
        @scribe.should_receive(:setup_remote)
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
        @scribe.config[:chronicle_path].should == Chef::Knife::ScribeHire::DEFAULT_CHRONICLE_PATH
        @scribe.config[:remote_name].should == Chef::Knife::ScribeHire::DEFAULT_REMOTE_NAME
        @scribe.config[:remote_url].should be_nil
      end
    end

    describe "when configuration is given through knife config" do
      before(:each) do
        Chef::Config[:knife][:scribe] = {}
        Chef::Config[:knife][:scribe][:chronicle_path] = Chef::Knife::ScribeHire::DEFAULT_CHRONICLE_PATH + "_knife"
        Chef::Config[:knife][:scribe][:remote_name] =  Chef::Knife::ScribeHire::DEFAULT_REMOTE_NAME + "_knife"
        Chef::Config[:knife][:scribe][:remote_url] =  "remote_url_knife"
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
          @scribe.config[:remote_url].should == Chef::Config[:knife][:scribe][:remote_url]
        end
      end

      describe "when command line configuration is given" do
        before(:each) do
          @scribe.config[:chronicle_path] = Chef::Knife::ScribeHire::DEFAULT_CHRONICLE_PATH + "_cmd"
          @scribe.config[:remote_name] =  Chef::Knife::ScribeHire::DEFAULT_REMOTE_NAME + "_cmd"
          @scribe.config[:remote_url] = "remote_url_cmd"
        end

        it "uses the configuration from command line" do
          @scribe.configure
          @scribe.config[:chronicle_path].should == Chef::Knife::ScribeHire::DEFAULT_CHRONICLE_PATH + "_cmd"
          @scribe.config[:remote_name].should == Chef::Knife::ScribeHire::DEFAULT_REMOTE_NAME + "_cmd"
          @scribe.config[:remote_url].should == "remote_url_cmd"
        end
      end
    end
  end


  describe "#init_chronicle" do
    it "invokes the git init shell command" do
      @scribe.should_receive(:shell_out!).with("git init", { :cwd => @scribe.config[:chronicle_path] })
      @scribe.init_chronicle
    end
  end

  describe "#setup_remote" do
    describe "when both remote name and url are set" do
      before(:each) do
        @remote_url = "a_repo_url"
        @remote_name = "a_repo_name"
        @scribe.config[:remote_url] = @remote_url
        @scribe.config[:remote_name] = @remote_name
      end

      it "checks if a remote with this name already exists" do
        command_response = double('shell_out')
        command_response.stub(:exitstatus) { 1 }
        @scribe.stub(:shell_out!) { command_response }
        expected_command = "git config --get remote.#{@remote_name}.url"
        @scribe.should_receive(:shell_out!).with(expected_command,
                                                     :cwd => @scribe.config[:chronicle_path],
                                                     :returns => [0,1,2])
        @scribe.setup_remote
      end

      describe "when the remote of that name does not exist" do
        it "adds a new remote" do
          command_response = double('shell_out')
          command_response.stub(:exitstatus) { 1 }
          expected_command = "git config --get remote.#{@remote_name}.url"
          @scribe.should_receive(:shell_out!).with(expected_command,
                                                       :cwd => @scribe.config[:chronicle_path],
                                                       :returns => [0,1,2]).and_return(command_response)
          add_remote_command = "git remote add #{@remote_name} #{@remote_url}"
          @scribe.should_receive(:shell_out!).with(add_remote_command,
                                                       :cwd => @scribe.config[:chronicle_path])
          @scribe.setup_remote
        end
      end

      describe "when a remote with a given name has already been configured" do
        describe "when it has a different url" do
          it "updates the remote url" do
            command_response = double('shell_out')
            command_response.stub(:exitstatus) { 0 }
            command_response.stub(:stdout) { "previous" + @remote_url }
            expected_command = "git config --get remote.#{@remote_name}.url"
            @scribe.should_receive(:shell_out!).with(expected_command,
                                                         :cwd => @scribe.config[:chronicle_path],
                                                         :returns => [0,1,2]).and_return(command_response)
            update_remote_url_command = "git config --replace-all remote.#{@remote_name}.url #{@remote_url}"
            @scribe.should_receive(:shell_out!).with(update_remote_url_command,
                                                         :cwd => @scribe.config[:chronicle_path])
            @scribe.setup_remote
          end
        end


        describe "when it has multiple values" do
          it "resets the url" do
            command_response = double('shell_out')
            command_response.stub(:exitstatus) { 2 }
            command_response.stub(:stdout) { "previous" + @remote_url }
            expected_command = "git config --get remote.#{@remote_name}.url"
            @scribe.should_receive(:shell_out!).with(expected_command,
                                                         :cwd => @scribe.config[:chronicle_path],
                                                         :returns => [0,1,2]).and_return(command_response)
            update_remote_url_command = "git config --replace-all remote.#{@remote_name}.url #{@remote_url}"
            @scribe.should_receive(:shell_out!).with(update_remote_url_command,
                                                         :cwd => @scribe.config[:chronicle_path])
            @scribe.setup_remote
          end
        end

        describe "when it has the same url" do
          it "does nothing" do
            command_response = double('shell_out')
            command_response.stub(:exitstatus) { 0 }
            command_response.stub(:stdout) { @remote_url }
            expected_command = "git config --get remote.#{@remote_name}.url"
            @scribe.should_receive(:shell_out!).with(expected_command,
                                                         :cwd => @scribe.config[:chronicle_path],
                                                         :returns => [0,1,2]).and_return(command_response)
            @scribe.should_receive(:shell_out!).exactly(0).times
            @scribe.setup_remote
          end
        end
      end
    end

    describe "when only the remote url is set" do
      before(:each) do
        @remote_url = "a_repo_url"
        @default_remote_name = "origin"
        @scribe.config[:remote_url] = @remote_url
      end

      it "uses a default remote name" do
        command_response = double('shell_out')
        command_response.stub(:exitstatus) { 1 }
        expected_command = "git config --get remote.#{@default_remote_name}.url"
        @scribe.should_receive(:shell_out!).with(expected_command,
                                                     :cwd => @scribe.config[:chronicle_path],
                                                     :returns => [0,1,2]).and_return(command_response)
        add_remote_command = "git remote add #{@default_remote_name} #{@remote_url}"
        @scribe.should_receive(:shell_out!).with(add_remote_command,
                                                     :cwd => @scribe.config[:chronicle_path])
        @scribe.setup_remote
      end
    end
  end
end
