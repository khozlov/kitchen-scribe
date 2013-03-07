Kitchen Scribe
==============

DESCRIPTION
-----------

This is a small Knife plugin for keeping track of various changes in your Chef environemnt.

In it's core it pulls the configuration of all your environements, roles, and nodes then saves them into json files in the place of your choosing and commits it using a local git repository. It can also pull/push them to a remote repostory for safekeeping.

The plugin is in an early alpha (as indicated by the commit dates) so things may change rather drastically in the near future.

USAGE
-----

Currently Kitchen Scribe can perform two actions.

First you need to hire a scribe using `knife scribe hire`. By default this will initialize a local directory called `.chronicle` where all backups will be performed. This task takes the following parameters:

* `-p` or `--chronicle-path` followed by a path allows you to specify a different location for the backup dir.
* `-r` or `--remote-url` followed by a git remote url will set up a remote in the backup dir pointing to the specified url. By default the name of the remote will be `origin`
* `--remote-name` followed by a remote_name allows you to specify a name for the remote repository. If `-r` is not used this has no effect.

`hire` action can be performed multiple times to set up additional remotes.

Next you probably want to get your scribe to actually do something for a change. `knife scribe copy` will fully back up your `roles` and `environments` and partially backup your `nodes` (only `name`, `env`, `attributes` and `run_list`). It assumes that you already hired your scribe and by default will look for your chronicle at `.chronicle`, assume that your remote name is `origin`, your default branch name is `master` and you want each of your commit messages to say _"Commiting chef state as of [current date and time]"_. Again you may customize this using:

* `-p` or `--chronicle-path` followed by a path to specify a different location for the chronicle.
* `--remote-name` followed by a remote_name to specify a different remote name.
* `--branch` followed by a branch name to indicate that you want to use a different branch.
* `-m` or `--commit-message` followed by a message to, suprise, suprise, specify your own custom message (use `%TIME%` anywhere in the message to get it substitued with current time).

You can also specify all the params in your `knife.rb` not to type it in every time by putting a config hash in there:

    knife[:scribe] = { :chronicle_path => "your_path",
                       :remote_name => "your_remote_name",
                       :remote_url => "your_remote_url",
                       :branch => "your_branch",
                       :commit_message => "your_commit_message"                                                                                                                                                        
    }
Have fun!

WHAT'S THE PLAN?
----------------

- Turn Scribe into a gem
- Mysterious Next Step ;-)

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
