Kitchen Scribe
==============

DESCRIPTION
-----------

This is a small Knife plugin for making and keeping track of various changes in your Chef environemnt.

It performs two main functions. 

1.  _Documenting changes_. It pulls the configuration of all your environements, roles, and nodes then saves them into json files in the place of your choosing and commits the changes to a local git repository. It can also pull/push them to a remote repostory for safekeeping.

2.  _Making precise changes_. It can perform precise updates on your environments, roles and nodes by using json data structure describing the change. *[This feature is still being tested and it's not available through rubygems yet. If you would like to try it please install it driectly from the github repo]* 

The philosophy behind using scribe to update your environments, roles an nodes is that you may want to make prepare some changes in advance, be able to test them and then have them applied to the final setup. Also it might be important to isolate those changes in a clear way so people who are not familiar with chef don't have to edit a huge json object to get them in. Lastly you can now automate applying your changes as well, and automation is what Chef is all about in the end:). 

The plugin is still in the beta stage, I've tested it manualy to some extent, but I'm sure there are things I missed. Please submit any bugs you find through the github issue system and I promiss to take care of them as soon as possible.

[![Code Climate](https://codeclimate.com/github/khozlov/kitchen-scribe.png)](https://codeclimate.com/github/khozlov/kitchen-scribe)
[![Gem Version](https://badge.fury.io/rb/kitchen-scribe.png)](http://badge.fury.io/rb/kitchen-scribe)

USAGE
-----

Install as gem using `gem install kitchen-scribe`.

### Documenting Changes

First you need to hire a scribe using `knife scribe hire`. By default this will initialize a local directory called `.chronicle` where all backups will be performed. This task takes the following parameters:

*   `-p` or `--chronicle-path` followed by a path allows you to specify a different location for the backup dir.
*   `-r` or `--remote-url` followed by a git remote url will set up a remote in the backup dir pointing to the specified url. By default the name of the remote will be `origin`
*   `--remote-name` followed by a remote_name allows you to specify a name for the remote repository. If `-r` is not used this has no effect.

`hire` action can be performed multiple times to set up additional remotes.

Next you probably want to get your scribe to actually do something for a change. `knife scribe copy` will fully back your `roles` and `environments` up and partially back your `nodes` up (only `name`, `env`, `attributes` and `run_list`). It assumes that you already hired your scribe and by default will look for your chronicle at `.chronicle`, assume that your remote name is `origin`, your default branch name is `master` and you want each of your commit messages to say _"Commiting chef state as of [current date and time]"_. Again you may customize this using:

*   `-p` or `--chronicle-path` followed by a path to specify a different location for the chronicle.
*   `--remote-name` followed by a remote_name to specify a different remote name.
*   `--branch` followed by a branch name to indicate that you want to use a different branch.
*   `-m` or `--commit-message` followed by a message to, suprise, suprise, specify your own custom message (use `%TIME%` anywhere in the message to get it substitued with current time).

You can also specify all the params in your `knife.rb` not to type it in every time by putting a config hash in there:

    knife[:scribe] = { :chronicle_path => "your_path",
                       :remote_name => "your_remote_name",
                       :remote_url => "your_remote_url",
                       :branch => "your_branch",
                       :commit_message => "your_commit_message"
                     }

### Making Changes

`adjust` action is your friend here.

I takes any amount of filenames (but at least one) with the changes specified in a JSON object. Apart from `author_name`, `author_email` and `description` which aren't mandatory this object needs to contain a property called `adjustments` that will in turn be an array of JSON objects containing at least the following properties:

*   `action` - The actual action to perform.
*   `type` - What you are trying to update. It can be either `environment`, `role` or `node`
*   `search` - the search query that will be used to figure out what to update. If a simple string is given (without a `:` character) scribe will assume it's a name and act accordingly 
*   `adjustment` - the hash containing the actual changes

The action to perform can be one of the following:

*   `merge` - a deep merge that combines the chef object with the adjustment, adding new entries and updating values. Arrays will be combined.
*   `hash_only_merge` - same as merge but arrays will be overwritten instead of combined (only in Chef version 11.0+).
*   `overwrite` - a simple merge on the top level of the chef object. Usefull for overwriting run lists.
*   `delete` - as the name suggests it can be used to delete parts of the config. The adjustment may be an integer or string in which case scribe will attempt to remove this key from the objec at the top level. It can be hash, which scribe treats as a map to the key that needs to be removed. Finally It can be an array which represents a set of changes that needs to be done on a single level. A quick example:

    With a simple envrionment

        { "chef_type": "environment"
          "cookbook_versions": { "apache2": "<= 1.1.8",
                                 "apt": "<= 1.4.9"
                               },
          "default_attributes": { "env" : "dev",
                                  "ports" : [ 80, 8080 ],
                                  "app" : { "storage_method" : "s3",
                                            "storage_url" : "foo.bar"
                                          }
                                }
        }

    Applying the folowing `delete` adjustment

        { "default_attributes" : [ "env",
                                   { "app" : "storage_method" },
                                   { "ports" : 0 }
			                     ],
		  "cookbook_versions" : "apt"
	    }

    Will remove default_attributes/env, default_attributes/app/storage_method, cookbook_versions/apt keys and first port from the default_attributes/ports array. The final product will be:

        { "chef_type": "environment"
          "cookbook_versions": { "apache2": "<= 1.1.8" }
          "default_attributes": { "ports" : [ 8080 ],
                                  "app" : { "storage_url" : "foo.bar" }
          }
        }

You can use `adjust` with a `-g` or `--generate` option. It will then fill all the files specified with an adjustment template (overwriting any existing content of the files).

An additional option `-t` or `--type` allows you to decide what adjustment template should be used (possible variants are `environment`, `role` and `node` - `environment` being the default)

Runing `adjust` with a `--dryrun` option won't update any objects on the server, but will allow you to review the result of your adjustments in a diff format.

Lastly you can use the `-d` or `--document` option which will surround your adjustments with a `scribe copy` action (initializing the repo with `scribe hire` just in case). It will use the same configuration form your `knife.rb` file that a standalone call to `hire` or `copy` would. You can also use the same command line prameters (`--chronicle-path`, `--remote-name`, `--remote-url` and `--branch`) to set everything up.

**Important note:** When you're trying to apply a change to all your environemnts, don't use `*:*` as your search term. Chef will then try to apply those changes to the `_default` environemnt which is frozen and can't me modified. Try using `-name:_default` instead. 

Have fun!

WHAT'S NEXT
-----------
* Refactoring, refactoring, refactoring
* Testing
* Bug fixes

LICENSE
-------
|                      |                                             |
|:---------------------|:--------------------------------------------|
| **Author:**          | Pawel Kozlowski (<pawel.kozlowski@u2i.com>)  
| **Copyright:**       | Copyright (c) 2013 Pawel Kozlowski  
| **License:**         | Apache License, Version 2.0  

Licensed under the Apache License, Version 2.0 (the “License”); you may not use this file except in compliance with the License. You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
