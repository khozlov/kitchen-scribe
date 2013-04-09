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
        @scribe.ui.should_receive(:fatal)
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

        it "generates adjustment templates for each filename specified" do
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

    it "saves the template JSON into the specified file" do
      File.should_receive(:open).with(@filename, "w").and_yield(@f1)
      @f1.should_receive(:write).with(JSON.pretty_generate(Chef::Knife::ScribeAdjust::TEMPLATE_HASH))
      @scribe.generate_template @filename
    end
  end

  describe "#apply_adjustment" do
    before(:each) do
      @filename = "spec1.json"
      @file = double("adjustment file")
      File.stub(:open).and_yield(@file)
    end

    it "parses the adjustment file" do
      File.should_receive(:open).with(@filename, "r").and_yield(@file)
      JSON.should_receive(:load).with(@file)
      @scribe.ui.stub(:fatal)
      @scribe.apply_adjustment(@filename)
    end

    describe "when the adjustment hash is not a Hash" do
      it "writes an appropriate message through the ui" do
        JSON.should_receive(:load).and_return(1)
        @scribe.ui.should_receive(:fatal)
        @scribe.apply_adjustment(@filename)
        JSON.should_receive(:load).and_return([])
        @scribe.ui.should_receive(:fatal)
        @scribe.apply_adjustment(@filename)
        JSON.should_receive(:load).and_return(nil)
        @scribe.ui.should_receive(:fatal)
        @scribe.apply_adjustment(@filename)
        JSON.should_receive(:load).and_return("test")
        @scribe.ui.should_receive(:fatal)
        @scribe.apply_adjustment(@filename)
      end
    end

    describe "when the adjustment hash is missing a value" do
      it "writes an appropriate message through the ui" do
        JSON.should_receive(:load).and_return({ "type" => "environment",
                                       "search" => "",
                                       "adjustment" => { }
                                     })
        @scribe.ui.should_receive(:fatal)
        @scribe.apply_adjustment(@filename)
        JSON.should_receive(:load).and_return({ "action" => "merge",
                                       "search" => "",
                                       "adjustment" => { }
                                     })
        @scribe.ui.should_receive(:fatal)
        @scribe.apply_adjustment(@filename)
        JSON.should_receive(:load).and_return({ "action" => "merge",
                                       "type" => "environment",
                                       "adjustment" => { }
                                     })
        @scribe.ui.should_receive(:fatal)
        @scribe.apply_adjustment(@filename)
        JSON.should_receive(:load).and_return({ "action" => "merge",
                                       "type" => "environment",
                                       "search" => ""
                                     })
        @scribe.ui.should_receive(:fatal)
        @scribe.apply_adjustment(@filename)
      end
    end

    describe "when the adustment hash contains all required keys" do
      before(:each) do
        @adjustment_hash = { "action" => "merge",
          "type" => "environment",
          "search" => "test",
          "adjustment" => { "a" => 1, "b" => 2 }
        }
        JSON.stub(:load).and_return(@adjustment_hash)
        @chef_query = double("Chef query")
      end

      describe "when action is incorrect" do
        it "returns with ui fatal message" do
          @scribe.should_receive(:respond_to?).with(@adjustment_hash["action"]).and_return(false)
          @scribe.ui.should_receive(:fatal)
          @scribe.apply_adjustment(@filename)
        end
      end

      describe "when action is incorrect" do
        before(:each) do
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

        it "merges each search result with the adjustment" do
          chef_obj = double("chef_object")
          chef_obj.stub(:to_hash).and_return( { "a" => 3, "c" => 3 } )
          chef_obj_class = double("chef_object_class")
          json_create_return_obj = double("final_chef_object")
          json_create_return_obj.stub(:save)
          chef_obj_class.stub(:json_create).and_return(json_create_return_obj)
          chef_obj.stub(:class).and_return(chef_obj_class)
          @query.should_receive(:search).with(@adjustment_hash["type"], "name:" + @adjustment_hash["search"]).and_yield(chef_obj)
          @scribe.should_receive(("action_" + @adjustment_hash["action"]).to_sym).with(chef_obj.to_hash, @adjustment_hash["adjustment"]).and_return({ "a" => 1, "b" => 2, "c" => 3})
          @scribe.apply_adjustment(@filename)
        end
      end
    end
  end
end
