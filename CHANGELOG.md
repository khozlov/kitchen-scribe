## 0.3.0

Bugfixes:

* Adjusting a node was overwriting normal attributes and erasing automatic attributes set by ohai. This is no longer the case.
* Updated all adjustment templates
* Changed the name for node attributes stored by scribe copy to `normal` to make loading configurations from chronicle backups more convinient

## 0.2.0

Features:

* Added `scribe hire` for making precise updates to environments, roles and nodes by using json data structure describing the change.

## 0.1.0

Features:

* First edition of `scribe` with a single directive called `copy`. It pulls the configuration of all your environements, roles, and nodes then saves them into json files in the place of your choosing and commits the changes to a local git repository. It can also pull/push them to a remote repostory for safekeeping. 