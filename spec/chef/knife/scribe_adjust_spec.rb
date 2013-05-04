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

describe Chef::Knife::ScribeAdjust do
  before(:each) do
    @scribe = Chef::Knife::ScribeAdjust.new
    @scribe.stub(:ui).and_return(double("ui", :fatal => nil, :error => nil))
  end

  it "responds to #action_merge" do
    @scribe.should respond_to(:action_merge)
  end

  it "responds to #action_hash_only_merge" do
    @scribe.should respond_to(:action_hash_only_merge)
  end

  it "responds to #action_overwrite" do
    @scribe.should respond_to(:action_overwrite)
  end

  it "responds to #action_delete" do
    @scribe.should respond_to(:action_delete)
  end

  describe "#run" do

    describe "when no files were given as parameters" do
      before(:each) do
        @scribe.name_args = [ ]
      end

      it "should show usage and exit if not filename is provided" do
        @scribe.name_args = []
        @scribe.ui.should_receive(:fatal).with("At least one adjustment file needs to be specified!")
        @scribe.should_receive(:show_usage)
        lambda { @scribe.run }.should raise_error(SystemExit)
      end
    end

    describe "when files were given in parameters" do
      before(:each) do
        @scribe.name_args = [ "spec1.json", "spec2.json" ]
        @scribe.stub(:write_adjustments)
        @scribe.stub(:generate_template)
        @scribe.stub(:parse_adjustment_file)
        @scribe.stub(:hire)
        @scribe.stub(:record_state)
      end

      describe "when generate option has been provided" do
        before(:each) do
          @scribe.config[:generate] = true
        end

        it "generates adjustment templates for each filename specified" do
          @scribe.name_args.each { |filename| @scribe.should_receive(:generate_template).with(filename) }
          @scribe.run
        end

        it "doesn't atttempt to writes out adjustments" do
          @scribe.should_not_receive(:write_adjustments)
          @scribe.run
        end

      end

      describe "when generate option has not been provided" do
        before(:each) do
          @scribe.config[:generate] = nil
        end

        it "initializes error structure for each file" do
          @scribe.name_args.each { |filename| @scribe.errors.should_receive(:push).with({"name" => filename, "general" => nil, "adjustments" => {}}) }
          @scribe.run
        end

        it "parses all adjustments specified" do
          @scribe.name_args.each { |filename| @scribe.should_receive(:parse_adjustment_file).with(filename) }
          @scribe.run
        end

        describe "when no errors occured" do
          before(:each) do
            @scribe.stub(:errors?).and_return(false)
          end

          it "doesn't print errors" do
            @scribe.should_not_receive(:print_errors)
            @scribe.run
          end


          it "writes out all adjustments" do
            @scribe.should_receive(:write_adjustments)
            @scribe.run
          end

          describe "when document option has been enabled" do
            before(:each) do
              @scribe.config[:document] = true
              @scribe.descriptions.push("Foo").push("Bar")
            end

            it "hires a scribe" do
              @scribe.should_receive(:hire)
              @scribe.run
            end

            it "records the initial and final state of the system" do
              @scribe.should_receive(:record_state).with(no_args()).ordered
              @scribe.should_receive(:record_state).with("Foo\nBar").ordered
              @scribe.run
            end
          end

          describe "when document option hasn't' been anabled" do
            before(:each) do
              @scribe.config[:document] = false
            end

            it "doesn't hire a scribe" do
              @scribe.should_not_receive(:hire)
              @scribe.run
            end

            it "doesn't record the initial and final state of the system" do
              @scribe.should_not_receive(:record_state)
              @scribe.run
            end
          end
        end

        describe "when errors occured" do
          before(:each) do
            @scribe.stub(:errors?).and_return(true)
          end

          it "doesn't write out any adjustments" do
            @scribe.should_not_receive(:write_adjustments)
            lambda { @scribe.run }.should raise_error(SystemExit)
          end

          it "prints errors" do
            @scribe.should_receive(:print_errors)
            lambda { @scribe.run }.should raise_error(SystemExit)
          end
        end
      end
    end
  end

  describe "#generate_template" do
    before(:each) do
      @f1 = double()
      @f1.stub(:write)
      @filename = "spec1.json"
    end

    describe "when type param is 'enviroment'" do
      before(:each) do
        @scribe.config[:type] = "environment"
      end

      it "saves the environment template JSON into the specified file" do
        File.should_receive(:open).with(@filename, "w").and_yield(@f1)
        Chef::Knife::ScribeAdjust::TEMPLATE_HASH["adjustments"] = [Chef::Knife::ScribeAdjust::ENVIRONMENT_ADJUSTMENT_TEMPLATE]
        @f1.should_receive(:write).with(JSON.pretty_generate(Chef::Knife::ScribeAdjust::TEMPLATE_HASH))
        @scribe.generate_template @filename
      end
    end

    describe "when type param is 'node'" do
      before(:each) do
        @scribe.config[:type] = "node"
      end

      it "saves the environment template JSON into the specified file" do
        File.should_receive(:open).with(@filename, "w").and_yield(@f1)
        Chef::Knife::ScribeAdjust::TEMPLATE_HASH["adjustments"] = [Chef::Knife::ScribeAdjust::NODE_ADJUSTMENT_TEMPLATE]
        @f1.should_receive(:write).with(JSON.pretty_generate(Chef::Knife::ScribeAdjust::TEMPLATE_HASH))
        @scribe.generate_template @filename
      end
    end

    describe "when type param is 'role'" do
      before(:each) do
        @scribe.config[:type] = "role"
      end

      it "saves the environment template JSON into the specified file" do
        File.should_receive(:open).with(@filename, "w").and_yield(@f1)
        Chef::Knife::ScribeAdjust::TEMPLATE_HASH["adjustments"] = [Chef::Knife::ScribeAdjust::ROLE_ADJUSTMENT_TEMPLATE]
        @f1.should_receive(:write).with(JSON.pretty_generate(Chef::Knife::ScribeAdjust::TEMPLATE_HASH))
        @scribe.generate_template @filename
      end
    end

    describe "when type param is not recognized" do
      before(:each) do
        @scribe.config[:type] = "xxxx"
      end

      it "throws an error through the ui and returns" do
        @scribe.ui.should_receive(:fatal).with("Incorrect adjustment type! Only 'node', 'environment' or 'role' allowed.")
        lambda { @scribe.generate_template @filename }.should raise_error(SystemExit)
      end
    end
  end

  describe "record_state" do
    before(:each) do
      @copyist_config = double("copyist config", :[]= => nil)
      @copyist = double("copyist", :run => nil, :config => @copyist_config)
      @scribe.config[:chronicle_path] = "test_path"
      @scribe.config[:remote_url] = "test_remote_url"
      @scribe.config[:remote_name] = "test_remote_name"
      Chef::Knife::ScribeCopy.stub(:new).and_return(@copyist)
    end

    describe "when called for the first time" do
      it "creates and runs a new instance of ScribeCopy" do
        Chef::Knife::ScribeCopy.should_receive(:new).and_return(@copyist)
        @copyist.should_receive(:run)
        @scribe.record_state
      end

      it "passes all relevant config variables to the hired scribe" do
        [:chronicle_path, :remote_name, :branch].each { |key| @copyist_config.should_receive(:[]=).with(key, @scribe.config[key]) }
        @scribe.record_state
      end
    end

    describe "when not called for the first time" do
      before(:each) do
        @scribe.record_state
      end

      it "creates and runs a new instance of ScribeCopy" do
        Chef::Knife::ScribeCopy.should_not_receive(:new)
        @copyist.should_receive(:run)
        @scribe.record_state
      end

      it "doesn't reconfigure the copyist" do
        [:chronicle_path, :remote_name, :branch].each { |key| @copyist_config.should_not_receive(:[]=).with(key, @scribe.config[key]) }
        @scribe.record_state
      end
    end

    it "passes its argument as the message for the scribe" do
      arg = double("argument")
      @copyist_config.should_receive(:[]=).with(:message, arg)
      @scribe.record_state(arg)
    end
  end

  describe "hire" do
    before(:each) do
      @hired_scribe_config = double("hired scribe config", :[]= => nil)
      @hired_scribe = double("hired scribe", :run => nil, :config => @hired_scribe_config)
      @scribe.config[:chronicle_path] = "test_path"
      @scribe.config[:remote_url] = "test_remote_url"
      @scribe.config[:remote_name] = "test_remote_name"
      Chef::Knife::ScribeHire.stub(:new).and_return(@hired_scribe)
    end

    it "creates and runs a new instance of ScribeHire" do
      Chef::Knife::ScribeHire.should_receive(:new).and_return(@hired_scribe)
      @hired_scribe.should_receive(:run)
      @scribe.hire
    end

    it "passes all relevant config variables to the hired scribe" do
      [:chronicle_path, :remote_url, :remote_name].each { |key| @hired_scribe_config.should_receive(:[]=).with(key, @scribe.config[key]) }
      @scribe.hire
    end
  end

  describe "#adjustment_file_valid?" do
    before(:each) do
      @scribe.errors.push({"name" => "filename", "general" => nil, "adjustments" => {}})
    end

    describe "when the contants of the file is not a Hash" do
      it "saves an appropriate general error to the error hash and returns false" do
        [1,[],nil,"test"].each do |not_a_hash|
          @scribe.errors.last.should_receive(:[]=).with("general", "Adjustment file must contain a JSON hash!")
          @scribe.adjustment_file_valid?(not_a_hash).should be_false
        end
      end
    end

    describe "when the adjustment hash is missing 'adjustments'" do
      it "saves an appropriate general error to the error hash and returns false" do
        parsed_file = { "author_email" => "test@mail.com",
          "author_name" => "test",
          "description" => "test description"
        }
        @scribe.errors.last.should_receive(:[]=).with("general", "Adjustment file must contain an array of adjustments!")
        @scribe.adjustment_file_valid?(parsed_file).should be_false
      end
    end

    describe "when the adjustment hash is missing 'adjustments' key or it doesn't point to an array" do
      it "saves an appropriate general error to the error hash and returns false" do
        parsed_file = { "author_email" => "test@mail.com",
          "author_name" => "test",
          "description" => "test description",
          "adjustments" => 1
        }
        [1,{},nil,"test"].each do |not_an_array|
          parsed_file["adjustments"] = not_an_array
          @scribe.errors.last.should_receive(:[]=).with("general", "Adjustment file must contain an array of adjustments!")
          @scribe.adjustment_file_valid?(parsed_file).should be_false
        end
      end
    end
  end

  describe "#adjustment_valid?" do
    before(:each) do
      @scribe.errors.push({"name" => "filename", "general" => nil, "adjustments" => {}})
    end

    describe "when the adjustment hash is not a Hash" do
      it "writes an appropriate adjustment related message into the errors hash and returns false" do
        [1,[],nil,"test"].each do |not_a_hash|
          @scribe.errors.last["adjustments"].should_receive(:store).with(0, "Adjustment must be a JSON hash!")
          @scribe.adjustment_valid?(not_a_hash, 0).should be_false
        end
      end
    end

    describe "when the adjustment hash is missing a value" do
      it "writes an appropriate adjustment related message into the errors hash and returns false" do
        complete_params_hash = { "action" => "merge",
          "type" => "node",
          "search" => "name:test",
          "adjustment" => { }
        }
        complete_params_hash.keys.each do |missing_param|
          incomplete_params_hash = complete_params_hash.clone
          incomplete_params_hash.delete(missing_param)
          @scribe.errors.last["adjustments"].should_receive(:store).with(0, "Adjustment hash must contain " + missing_param + "!")
          @scribe.adjustment_valid?(incomplete_params_hash, 0).should be_false
        end
      end
    end

    describe "when action is incorrect" do
      before(:each) do
        @adjustment_hash = { "action" => "xxxxxx",
          "type" => "environment",
          "search" => "test",
          "adjustment" => { "a" => 1, "b" => 2 }
        }
      end

      it "returns false with ui fatal message" do
        @scribe.should_receive(:respond_to?).with("action_" + @adjustment_hash["action"]).and_return(false)
        @scribe.errors.last["adjustments"].should_receive(:store).with(0, "Incorrect action!")
        @scribe.adjustment_valid?(@adjustment_hash, 0).should be_false
      end
    end

    describe "when action is correct" do
      before(:each) do
        @adjustment_hash = { "action" => "merge",
          "type" => "environment",
          "search" => "test",
          "adjustment" => { "a" => 1, "b" => 2 }
        }
      end

      it "returns true without any ui message" do
        @scribe.should_receive(:respond_to?).with("action_" + @adjustment_hash["action"]).and_return(true)
        @scribe.errors.last["adjustments"].should_not_receive(:store).with(0, "Incorrect action!")
        @scribe.adjustment_valid?(@adjustment_hash, 0).should be_true
      end
    end
  end

  describe "#write_adjustments" do
    before(:each) do
      @adjusted_env = double("adjusted environment")
      @adjusted_env.stub(:[]).with("chef_type").and_return("environment")
      @adjusted_node = double("adjusted node")
      @adjusted_node.stub(:[]).with("chef_type").and_return("node")
      @scribe.changes["environment:test_env"] = {
        "original" => { "chef_type" => "environment", "name" => "test_env" },
        "adjusted" => @adjusted_env
      }
      @scribe.changes["node:test_node"] = {
        "original" => { "chef_type" => "node", "name" => "test_node" },
        "adjusted" => @adjusted_node
      }
      @env_class = double("env class")
      @node_class = double("node class")
      @env_object = double("env object")
      @node_object = double("node_object")
    end

    it "saves each adjusted version on the chef server" do
      Chef.should_receive(:const_get).with("Environment").and_return(@env_class)
      @env_class.should_receive(:json_create).with(@adjusted_env).and_return(@env_object)
      @env_object.should_receive(:save)
      Chef.should_receive(:const_get).with("Node").and_return(@node_class)
      @node_class.should_receive(:json_create).with(@adjusted_node).and_return(@node_object)
      @node_object.should_receive(:save)
      @scribe.write_adjustments
    end
  end

  describe "#parse_adjustment_file" do
    before(:each) do
      @filename = "spec1.json"
      @file = double("adjustment file")
      File.stub(:open).and_yield(@file)
      File.stub(:open).with(@filename, "r").and_yield(@file)
      @adjustment_hash = { "author_name" => "test",
        "author_email" => "test@test.com",
        "description" => "test description",
        "adjustments" => [{ "action" => "BAD_ACTION",
                            "type" => "environment",
                            "search" => "test",
                            "adjustment" => { "a" => 1, "b" => 2 }
                          },
                          { "action" => "delete",
                            "type" => "node",
                            "search" => "foo:bar",
                            "adjustment" => [ "c" ]
                          }
                         ]
      }
      File.stub(:exists?).and_return(true)
      @scribe.stub(:apply_adjustment)
      @scribe.errors.push({"name" => @filename, "general" => nil, "adjustments" => {}})
    end

    it "checks if the file exists" do
      File.should_receive(:exists?).with(@filename).and_return(false)
      @scribe.parse_adjustment_file(@filename)
    end

    describe "when the file does not exist" do
      before(:each) do
        File.stub(:exists?).and_return(false)
      end

      it "writes a general error into the errors hash" do
        @scribe.errors.last.should_receive(:[]=).with("general", "File does not exist!")
        @scribe.parse_adjustment_file(@filename)
      end

      it "doesn't attempt to open the file" do
        File.should_not_receive(:open).with(@filename)
        @scribe.parse_adjustment_file(@filename)
      end
    end

    it "parses the adjustment file" do
      File.should_receive(:open).with(@filename, "r").and_yield(@file)
      JSON.should_receive(:load).with(@file).and_return(@adjustment_hash)
      @scribe.parse_adjustment_file(@filename)
    end

    describe "when the JSON file is malformed" do
      it "returns writes a fatal error through the ui" do
        @scribe.errors.last.should_receive(:[]=).with("general", "Malformed JSON!")
        @scribe.parse_adjustment_file(@filename)
      end

      it "doesn't throw an exception" do
        File.should_receive(:open).with(@filename, "r").and_yield('{"a" : 3, b => ]')
        lambda { @scribe.parse_adjustment_file(@filename) }.should_not raise_error(JSON::ParserError)
      end
    end

    describe "when the file exists and is well formed" do
      before(:each) do
        JSON.stub(:load).and_return(@adjustment_hash)
      end

      it "checks if the adjustment file is valid" do
        @scribe.should_receive(:adjustment_file_valid?).with(@adjustment_hash).and_return(false)
        @scribe.parse_adjustment_file(@filename)
      end

      describe "if the adjustment file is correct" do
        it "applies each adjustment if it's correct'" do
          @scribe.should_receive(:adjustment_valid?).with(@adjustment_hash["adjustments"][0], 0).and_return(false)
          @scribe.should_receive(:adjustment_valid?).with(@adjustment_hash["adjustments"][1], 1).and_return(true)
          @scribe.should_receive(:apply_adjustment).with(@adjustment_hash["adjustments"][1])
          @scribe.parse_adjustment_file(@filename)
        end
      end

      describe "if all adjustments are correct" do
        before(:each) do
          @scribe.stub(:adjustment_valid?).and_return(true)
        end

        it "adds the description to the descriptions array" do
          @scribe.descriptions.should_receive(:push).with(@adjustment_hash["description"])
          @scribe.parse_adjustment_file(@filename)
        end
      end


      describe "if at least one adjustment was correct" do
        before(:each) do
          @scribe.stub(:adjustment_valid?).and_return(true,false)
          @scribe.errors.last["adjustments"].store(1, "Foo")
        end

        it "adds the description to the descriptions array" do
          @scribe.descriptions.should_receive(:push).with(@adjustment_hash["description"] + "[with errors]")
          @scribe.parse_adjustment_file(@filename)
        end
      end

      describe "if no adjustment was correct" do
        before(:each) do
          @scribe.stub(:adjustment_valid?).and_return(false,false)
          @scribe.errors.last["adjustments"].store(0, "Foo")
          @scribe.errors.last["adjustments"].store(1, "Bar")
        end

        it "doesn't add the description to the descriptions array" do
          @scribe.descriptions.should_not_receive(:push).with(@adjustment_hash["description"])
          @scribe.parse_adjustment_file(@filename)
        end
      end
    end
  end

  describe "#apply_adjustment" do
    before(:each) do
      @adjustment = { "action" => "merge",
        "type" => "environment",
        "search" => "test",
        "adjustment" => { "a" => 1, "b" => 2 }
      }

      @scribe.stub(:adjustment_valid?).and_return(true)
      @query = double("Chef query")
      Chef::Search::Query.stub(:new).and_return(@query)
      @chef_obj = double("chef_object")
      @chef_obj.stub(:to_hash).and_return( { "name" => "test_name", "chef_type" => "test_type", "a" => 3, "c" => 3 } )
      chef_obj_class = double("chef_object_class")
      json_create_return_obj = double("final_chef_object")
      json_create_return_obj.stub(:save)
      chef_obj_class.stub(:json_create).and_return(json_create_return_obj)
      @chef_obj.stub(:class).and_return(chef_obj_class)
      @query.stub(:search).and_yield(@chef_obj)
    end

    describe "when search parameter doesn't contain a ':' character" do
      before(:each) do
        @adjustment["search"] = "test_name"
      end

      it "performs a search using the 'search' parameter as a name" do
        @query.should_receive(:search).with(@adjustment["type"], "name:" + @adjustment["search"])
        @scribe.apply_adjustment(@adjustment)
      end
    end

    describe "when search parameter contains a ':' character" do
      before(:each) do
        @adjustment["search"] = "foo:test_name"
      end

      it "performs a search using the 'search' parameter as a complete query" do
        @query.should_receive(:search).with(@adjustment["type"], @adjustment["search"])
        @scribe.apply_adjustment(@adjustment)
      end
    end

    it "checks if the a change to a given object is already pending" do
      @scribe.changes.should_receive(:has_key?).with(@chef_obj.to_hash["chef_type"] + ":" + @chef_obj.to_hash["name"])
      @scribe.apply_adjustment(@adjustment)
    end

    describe "if the key doesn't exist" do
      it "saves the original in the changes hash" do
        @scribe.changes.should_receive(:store).with(@chef_obj.to_hash["chef_type"] + ":" + @chef_obj.to_hash["name"],
                                                    { "original" => @chef_obj.to_hash }
                                                    ).and_call_original
        @scribe.apply_adjustment(@adjustment)
      end
    end

    it "applies each subsequent adjustment to the already adjusted version" do
      adjusted_hash = @chef_obj.to_hash.dup.merge({"a" => "b"})
      changes_hash = { "original" => @chef_obj.to_hash, "adjusted" => adjusted_hash }
      @scribe.changes[@chef_obj.to_hash["chef_type"] + ":" + @chef_obj.to_hash["name"]] = changes_hash
      @scribe.should_receive(("action_" + @adjustment["action"]).to_sym).with(adjusted_hash, @adjustment["adjustment"])
      @scribe.apply_adjustment(@adjustment)
    end

    it "saves the changed version in the changes hash" do
      adjusted_hash = @chef_obj.to_hash.dup.merge({ "a" => "b" })
      changes_hash = { "original" => @chef_obj.to_hash, "adjusted" => adjusted_hash }
      @scribe.changes[@chef_obj.to_hash["chef_type"] + ":" + @chef_obj.to_hash["name"]] = changes_hash
      adjusted_hash = @scribe.send(("action_" + @adjustment["action"]).to_sym, adjusted_hash, @adjustment["adjustment"])
      changes_hash.should_receive(:store).with("adjusted", adjusted_hash).and_call_original
      @scribe.apply_adjustment(@adjustment)
    end
  end

  describe "#action_overwrite" do
    it "performs a standard hash merge when both base and overwrite_with are hashes" do
      base = { "a" => 1, "b" => [1,2,3], "c" => { "x" => 1, "y" => 2 } }
      overwrite_with = { "b" => [4], "c" => { "z" => 1, "y" => 3}, "d" => 3 }
      base.should_receive(:merge).with(overwrite_with)
      @scribe.action_overwrite(base,overwrite_with)
    end

    it "returns base hash if overwrite_with is nil" do
      base = {"foo" => "bar"}
      overwrite_with = nil
      result = @scribe.action_overwrite(base,overwrite_with)
      result.should eq(base)
    end

    it "returns the overwrite if base is not a hash" do
      base = "test"
      overwrite_with = {"a" => 1}
      result = @scribe.action_overwrite(base,overwrite_with)
      result.should eq(overwrite_with)
    end
  end

  describe "#deep_delete" do
    it "calls #seedp_delete! with duplicates of it's arguments" do
      delete_from = double("delete_from")
      delete_spec = double("delete_spec")
      delete_from_dup = double("delete_from_dup")
      delete_spec_dup = double("delete_spec_dup")
      delete_from.should_receive(:dup).and_return(delete_from_dup)
      delete_spec.should_receive(:dup).and_return(delete_spec_dup)
      @scribe.should_receive(:deep_delete!).with(delete_from_dup, delete_spec_dup)
      @scribe.deep_delete(delete_from, delete_spec)
    end
  end

  describe "#deep_delete!" do
    describe "when both base and overwrite_with are hashes" do
      before(:each) do
        @delete_from = { "a" => 1, "b" => [3,2,1], "c" => { "x" => 1, "y" => 2 } }
      end

      describe "when the spec intructs it to delete a top level key" do
        before(:each) do
          @delete_spec = "c"
        end

        it "deletes it" do
          @scribe.deep_delete!(@delete_from,@delete_spec).keys.should_not include("c")
        end
      end

      describe "when the spec intructs it to delete a nested key" do
        before(:each) do
          @delete_spec = { "c" => "x" }
        end

        it "doesn't delete the top level key" do
          @scribe.deep_delete!(@delete_from,@delete_spec).keys.should include("c")
        end

        it "deletes it" do
          @scribe.deep_delete!(@delete_from,@delete_spec)["c"].keys.should_not include("x")
        end
      end

      describe "when the spec intructs it to delete an array key that exists" do
        before(:each) do
          @delete_spec = { "b" => 1 }
        end

        it "deletes it" do
          @scribe.deep_delete!(@delete_from,@delete_spec)["b"].should eq([3,1])
        end
      end

      describe "when the spec intructs it to delete an array key that doesn't exist" do
        before(:each) do
          @delete_spec = { "b" => 10 }
        end

        it "does nothing" do
          @scribe.deep_delete!(@delete_from,@delete_spec)["b"].should eq(@delete_from["b"])
        end
      end

      describe "when the spec intructs it to delete a hash key that doesn't exist" do
        before(:each) do
          @delete_spec = { "c" => { "not_here" => [1,2] } }
        end

        it "does nothing" do
          @scribe.deep_delete!(@delete_from,@delete_spec)["c"].should eq(@delete_from["c"])
        end
      end

      describe "when the spec intructs it to delete a set of nested keys" do
        before(:each) do
          @delete_spec = { "c" => ["x", "y"] }
        end

        it "doesn't delete the top level key" do
          @scribe.deep_delete!(@delete_from,@delete_spec).keys.should include("c")
        end

        it "deletes both of them" do
          @scribe.deep_delete!(@delete_from,@delete_spec)["c"].keys.should_not include("x","y")
        end
      end

      describe "when the spec intructs it to delete a set of top level keys" do
        before(:each) do
          @delete_spec = [ "b", "c"]
        end

        it "deletes both of them" do
          @scribe.deep_delete!(@delete_from,@delete_spec).keys.should_not include("b","c")
        end
      end

    end

    it "returns delete_from if delete_spec is nil" do
      delete_from = {"foo" => "bar"}
      delete_spec = nil
      result = @scribe.deep_delete!(delete_from,delete_spec)
      result.should eq(delete_from)
    end

    it "returns delete_from if delete_from is not a hash or an array" do
      base = "test"
      overwrite_with = {"a" => 1}
      result = @scribe.action_overwrite(base,overwrite_with)
      result.should eq(overwrite_with)
    end
  end

  describe "#errors?" do
    describe "when no errors have occured" do
      before(:each) do
        for i in 1..3
          @scribe.errors.push({"name" => "filename" + i.to_s, "general" => nil, "adjustments" => {}})
        end
      end

      it "returns false" do
        @scribe.errors?.should be_false
      end
    end

    describe "when general error has occured" do
      before(:each) do
        for i in 1..3
          @scribe.errors.push({"name" => "filename" + i.to_s, "general" => nil, "adjustments" => {}})
        end
        @scribe.errors.push({"name" => "filename4", "general" => "foo", "adjustments" => {}})
      end

      it "returns true" do
        @scribe.errors?.should be_true
      end
    end

    describe "when an adjustment specific error has occured" do
      before(:each) do
        @scribe.errors.push({"name" => "filename0", "general" => nil, "adjustments" => { 2 => "bar"}})
        for i in 1..3
          @scribe.errors.push({"name" => "filename" + i.to_s, "general" => nil, "adjustments" => {}})
        end
      end

      it "returns true" do
        @scribe.errors?.should be_true
      end
    end
  end

  describe "print_errors" do
    it "prints all the errors in the right format" do
      @scribe.errors.push({"name" => "filename1", "general" => nil, "adjustments" => {}})
      @scribe.errors.push({"name" => "filename2", "general" => nil, "adjustments" => { 2 => "bar"}})
      @scribe.errors.push({"name" => "filename3", "general" => "Foo", "adjustments" => {}})
      @scribe.ui.should_receive(:error).with("ERRORS OCCURED:")
      @scribe.ui.should_receive(:error).with("filename2")
      @scribe.ui.should_receive(:error).with("\t[Adjustment 2]: bar")
      @scribe.ui.should_receive(:error).with("filename3")
      @scribe.ui.should_receive(:error).with("\tFoo")
      @scribe.print_errors
    end
  end

end
