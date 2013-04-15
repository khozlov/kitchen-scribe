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
    before(:each) do
      @stdout = StringIO.new
      @scribe.ui.stub!(:stdout).and_return(@stdout)
    end

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
      end

      describe "when generate option has been provided" do
        before(:each) do
          @scribe.config[:generate] = true
        end

        it "generates adjustment templates for each filename specified" do
          @scribe.name_args.each { |filename| @scribe.should_receive(:generate_template).with(filename) }
          @scribe.run
        end
      end

      describe "when generate option has not been provided" do
        before(:each) do
          @scribe.config[:generate] = nil
        end

        it "applies all adjustments specified" do
          @scribe.name_args.each { |filename| @scribe.should_receive(:apply_adjustment).with(filename) }
          @scribe.run
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
        @f1.should_receive(:write).with(JSON.pretty_generate(Chef::Knife::ScribeAdjust::TEMPLATE_HASH.merge(Chef::Knife::ScribeAdjust::ENVIRONMENT_ADJUSTMENT_TEMPLATE)))
        @scribe.generate_template @filename
      end
    end

    describe "when type param is 'node'" do
      before(:each) do
        @scribe.config[:type] = "node"
      end

      it "saves the environment template JSON into the specified file" do
        File.should_receive(:open).with(@filename, "w").and_yield(@f1)
        @f1.should_receive(:write).with(JSON.pretty_generate(Chef::Knife::ScribeAdjust::TEMPLATE_HASH.merge(Chef::Knife::ScribeAdjust::NODE_ADJUSTMENT_TEMPLATE)))
        @scribe.generate_template @filename
      end
    end

    describe "when type param is 'role'" do
      before(:each) do
        @scribe.config[:type] = "role"
      end

      it "saves the environment template JSON into the specified file" do
        File.should_receive(:open).with(@filename, "w").and_yield(@f1)
        @f1.should_receive(:write).with(JSON.pretty_generate(Chef::Knife::ScribeAdjust::TEMPLATE_HASH.merge(Chef::Knife::ScribeAdjust::ROLE_ADJUSTMENT_TEMPLATE)))
        @scribe.generate_template @filename
      end
    end

    describe "when type param is not recognized" do
      before(:each) do
        @scribe.config[:type] = "xxxx"
        @stdout = StringIO.new
        @scribe.ui.stub!(:stdout).and_return(@stdout)
      end

      it "throws an error through the ui and returns" do
        @scribe.ui.should_receive(:fatal).with("Incorrect adjustment type! Only 'node', 'environment' or 'role' allowed.")
        lambda { @scribe.generate_template @filename }.should raise_error(SystemExit)
      end
    end
  end

  describe "#adjustment_valid?" do
    describe "when the adjustment hash is not a Hash" do
      it "writes an appropriate message through the ui and returns false" do
        [1,[],nil,"test"].each do |not_a_hash|
          @scribe.ui.should_receive(:fatal).with("Adjustment must be a JSON hash!")
          @scribe.adjustment_valid?(not_a_hash).should be_false
        end
      end
    end

    describe "when the adjustment hash is missing a value" do
      it "writes an appropriate message through the ui and returns flase" do
        complete_params_hash = { "action" => "merge",
          "type" => "node",
          "search" => "name:test",
          "adjustment" => { }
        }
        complete_params_hash.keys.each do |missing_param|
          incomplete_params_hash = complete_params_hash.clone
          incomplete_params_hash.delete(missing_param)
          @scribe.ui.should_receive(:fatal).with("Adjustment hash must contain " + missing_param + "!")
          @scribe.adjustment_valid?(incomplete_params_hash).should be_false
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
        @scribe.should_receive(:respond_to?).with(@adjustment_hash["action"]).and_return(false)
        @scribe.ui.should_receive(:fatal).with("Incorrect action!")
        @scribe.adjustment_valid?(@adjustment_hash).should be_false
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
        @scribe.should_receive(:respond_to?).with(@adjustment_hash["action"]).and_return(true)
        @scribe.ui.should_not_receive(:fatal).with("Incorrect action!")
        @scribe.adjustment_valid?(@adjustment_hash).should be_true
      end
    end

  end

  describe "#apply_adjustment" do
    before(:each) do
      @filename = "spec1.json"
      @file = double("adjustment file")
      File.stub(:open).and_yield(@file)
      File.stub(:open).with(@filename, "r").and_yield(@file)
      @adjustment_hash = { "action" => "merge",
        "type" => "environment",
        "search" => "test",
        "adjustment" => { "a" => 1, "b" => 2 }
      }
      File.stub(:exists?).and_return(true)
      @scribe.ui.stub(:fatal)
    end

    it "checks if the file exists" do
      File.should_receive(:exists?).with(@filename).and_return(false)
      @scribe.apply_adjustment(@filename)
    end

    describe "when the file does not exist" do
      before(:each) do
        File.stub(:exists?).and_return(false)
      end

      it "returns writes a fatal error through the ui" do
        @scribe.ui.should_receive(:fatal).with("File " + @filename + " does not exist!")
        @scribe.apply_adjustment(@filename)
      end

      it "doesn't attempt to open the file" do
        File.should_not_receive(:open).with(@filename)
        @scribe.apply_adjustment(@filename)
      end
    end

    it "parses the adjustment file" do
      File.should_receive(:open).with(@filename, "r").and_yield(@file)
      JSON.should_receive(:load).with(@file)
      @scribe.stub(:adjustment_valid?).and_return(false)
      @scribe.apply_adjustment(@filename)
    end

    describe "when the JSON file is malformed" do
      it "returns writes a fatal error through the ui" do
        @scribe.ui.should_receive(:fatal).with("Malformed JSON in " + @filename + "!")
        @scribe.apply_adjustment(@filename)
      end

      it "doesn't throw an exception" do
        File.should_receive(:open).with(@filename, "r").and_yield('{"a" : 3, b => ]')
        lambda { @scribe.apply_adjustment(@filename) }.should_not raise_error(JSON::ParserError)
      end
    end

    describe "when the file exists and is well formed" do
      before(:each) do
        JSON.stub(:load).and_return(@adjustment_hash)
      end

      it "checks if the adjustment is valid" do
        @scribe.should_receive(:adjustment_valid?).with(@adjustment_hash).and_return(false)
        @scribe.apply_adjustment(@filename)
      end

      describe "when the #adustment_valid? returns true" do
        before(:each) do
          @scribe.stub(:adjustment_valid?).and_return(true)
          @query = double("Chef query")
          Chef::Search::Query.stub(:new).and_return(@query)
        end

        describe "when search parameter doesn't contain a ':' character" do
          it "performs a search using the 'search' parameter as a name" do
            @query.should_receive(:search).with(@adjustment_hash["type"], "name:" + @adjustment_hash["search"])
            @scribe.apply_adjustment(@filename)
          end
        end

        describe "when search parameter contains a ':' character" do
          it "performs a search using the 'search' parameter as a complete query" do
            @adjustment_hash["search"] = "testkey:testvalue"
            @query.should_receive(:search).with(@adjustment_hash["type"], @adjustment_hash["search"])
            @scribe.apply_adjustment(@filename)
          end
        end

        it "applies the adjustment" do
          chef_obj = double("chef_object")
          chef_obj.stub(:to_hash).and_return( { "a" => 3, "c" => 3 } )
          chef_obj_class = double("chef_object_class")
          json_create_return_obj = double("final_chef_object")
          json_create_return_obj.stub(:save)
          chef_obj_class.stub(:json_create).and_return(json_create_return_obj)
          chef_obj.stub(:class).and_return(chef_obj_class)
          @query.stub(:search).with(@adjustment_hash["type"], "name:" + @adjustment_hash["search"]).and_yield(chef_obj)
          @scribe.should_receive(("action_" + @adjustment_hash["action"]).to_sym).with(chef_obj.to_hash, @adjustment_hash["adjustment"]).and_return({ "a" => 1, "b" => 2, "c" => 3})
          @scribe.apply_adjustment(@filename)
        end
      end
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
end
