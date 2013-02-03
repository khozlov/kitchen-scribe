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

describe KitchenScribe::ScribeHire do
  before(:each) do
    Dir.stub!(:mkdir)
    Dir.stub!(:pwd) { "some_path"}
    Chef::Config[:knife][:scribe] = {}
    @scribeHire = KitchenScribe::ScribeHire.new
  end

  describe "#run" do
    describe "with no chronicle path configuration" do
      before(:each) do
        @default_chonicle_dir_name = ".chronicle"
        @scribeHire.stub(:setup_remote)
        @scribeHire.stub(:init_chronicle)
      end

      it "creates the main chronicle directory in the default path" do
        Dir.should_receive(:mkdir).with(File.join("some_path", @default_chonicle_dir_name))
        @scribeHire.run
      end

      it "creates the environments subdirectory in the default path" do
        Dir.should_receive(:mkdir).with(File.join("some_path", @default_chonicle_dir_name, "environments"))
        @scribeHire.run
      end

      it "creates the nodes subdirectory in the default path" do
        Dir.should_receive(:mkdir).with(File.join("some_path", @default_chonicle_dir_name, "nodes"))
        @scribeHire.run
      end

      it "creates the roles subdirectory in the default path" do
        Dir.should_receive(:mkdir).with(File.join("some_path", @default_chonicle_dir_name, "roles"))
        @scribeHire.run
      end

      it "passes the default path to #setup_remote" do
        @scribeHire.should_receive(:setup_remote).with(File.join("some_path", @default_chonicle_dir_name))
        @scribeHire.run
      end

      it "passes the default path to #init_chronicle" do
        @scribeHire.should_receive(:init_chronicle).with(File.join("some_path", @default_chonicle_dir_name))
        @scribeHire.run
      end
    end

    describe "with chronicle path configuration present" do
      before(:each) do
        @chronicle_path = "some_other_path"
        Chef::Config[:knife][:scribe][:chronicle_path] = @chronicle_path
        @scribeHire.stub(:setup_remote)
        @scribeHire.stub(:init_chronicle)
      end

      it "creates the main chronicle directory in the default path" do
        Dir.should_receive(:mkdir).with(@chronicle_path)
        @scribeHire.run
      end

      it "creates the environments subdirectory in the default path" do
        Dir.should_receive(:mkdir).with(File.join(@chronicle_path, "environments"))
        @scribeHire.run
      end

      it "creates the nodes subdirectory in the default path" do
        Dir.should_receive(:mkdir).with(File.join(@chronicle_path, "nodes"))
        @scribeHire.run
      end

      it "creates the roles subdirectory in the default path" do
        Dir.should_receive(:mkdir).with(File.join(@chronicle_path, "roles"))
        @scribeHire.run
      end

      it "passes the default path to #setup_remote" do
        @scribeHire.should_receive(:setup_remote).with(File.join(@chronicle_path))
        @scribeHire.run
      end

      it "passes the default path to #init_chronicle" do
        @scribeHire.should_receive(:init_chronicle).with(File.join(@chronicle_path))
        @scribeHire.run
      end
    end
  end

  describe "#init_chronicle" do
    it "invokes the git init shell command" do
      @scribeHire.should_receive(:shell_out!).with("git init", { :cwd => "a_path" })
      @scribeHire.init_chronicle "a_path"
    end
  end

  describe "#setup_remote" do
    describe "when both remote name and url are set" do
      before(:each) do
        @remote_url = "a_repo_url"
        @remote_name = "a_repo_name"
        Chef::Config[:knife][:scribe][:remote_url] = @remote_url
        Chef::Config[:knife][:scribe][:remote_name] = @remote_name
      end

      it "checks if a remote with this name already exists" do
        command_response = double('shell_out')
        command_response.stub(:exitstatus) { 1 }
        @scribeHire.stub(:shell_out!) { command_response }
        expected_command = "git config --get remote.#{@remote_name}.url"
        @scribeHire.should_receive(:shell_out!).with(expected_command,
                                                     :cwd => "chronicle_path",
                                                     :returns => [0,1,2])
        @scribeHire.setup_remote "chronicle_path"
      end

      describe "when the remote of that name does not exist" do
        it "adds a new remote" do
          command_response = double('shell_out')
          command_response.stub(:exitstatus) { 1 }
          expected_command = "git config --get remote.#{@remote_name}.url"
          @scribeHire.should_receive(:shell_out!).with(expected_command,
                                                       :cwd => "chronicle_path",
                                                       :returns => [0,1,2]).and_return(command_response)
          add_remote_command = "git remote add #{@remote_name} #{@remote_url}"
          @scribeHire.should_receive(:shell_out!).with(add_remote_command,
                                                       :cwd => "chronicle_path")
          @scribeHire.setup_remote "chronicle_path"
        end
      end

      describe "when a remote with a given name has already been configured" do
        describe "when it has a different url" do
          it "updates the remote url" do
            command_response = double('shell_out')
            command_response.stub(:exitstatus) { 0 }
            command_response.stub(:stdout) { "previous" + @remote_url }
            expected_command = "git config --get remote.#{@remote_name}.url"
            @scribeHire.should_receive(:shell_out!).with(expected_command,
                                                         :cwd => "chronicle_path",
                                                         :returns => [0,1,2]).and_return(command_response)
            update_remote_url_command = "git config --replace-all remote.#{@remote_name}.url #{@remote_url}"
            @scribeHire.should_receive(:shell_out!).with(update_remote_url_command,
                                                         :cwd => "chronicle_path")
            @scribeHire.setup_remote "chronicle_path"
          end
        end


        describe "when it has multiple values" do
          it "resets the url" do
            command_response = double('shell_out')
            command_response.stub(:exitstatus) { 2 }
            command_response.stub(:stdout) { "previous" + @remote_url }
            expected_command = "git config --get remote.#{@remote_name}.url"
            @scribeHire.should_receive(:shell_out!).with(expected_command,
                                                         :cwd => "chronicle_path",
                                                         :returns => [0,1,2]).and_return(command_response)
            update_remote_url_command = "git config --replace-all remote.#{@remote_name}.url #{@remote_url}"
            @scribeHire.should_receive(:shell_out!).with(update_remote_url_command,
                                                         :cwd => "chronicle_path")
            @scribeHire.setup_remote "chronicle_path"
          end
        end

        describe "when it has the same url" do
          it "does nothing" do
            command_response = double('shell_out')
            command_response.stub(:exitstatus) { 0 }
            command_response.stub(:stdout) { @remote_url }
            expected_command = "git config --get remote.#{@remote_name}.url"
            @scribeHire.should_receive(:shell_out!).with(expected_command,
                                                         :cwd => "chronicle_path",
                                                         :returns => [0,1,2]).and_return(command_response)
            @scribeHire.should_receive(:shell_out!).exactly(0).times
            @scribeHire.setup_remote "chronicle_path"
          end
        end
      end
    end

    describe "when only the remote url is set" do
      before(:each) do
        @remote_url = "a_repo_url"
        @default_remote_name = "origin"
        Chef::Config[:knife][:scribe][:remote_url] = @remote_url
      end

      it "uses a default remote name" do
        command_response = double('shell_out')
        command_response.stub(:exitstatus) { 1 }
        expected_command = "git config --get remote.#{@default_remote_name}.url"
        @scribeHire.should_receive(:shell_out!).with(expected_command,
                                                     :cwd => "chronicle_path",
                                                     :returns => [0,1,2]).and_return(command_response)
        add_remote_command = "git remote add #{@default_remote_name} #{@remote_url}"
        @scribeHire.should_receive(:shell_out!).with(add_remote_command,
                                                     :cwd => "chronicle_path")
        @scribeHire.setup_remote "chronicle_path"
      end
    end

    describe "when remote url was not specified" do
      it "does nothing" do
        @scribeHire.should_not_receive(:shell_out!)
        @scribeHire.setup_remote "chronicle_path"
      end
    end
  end
end
