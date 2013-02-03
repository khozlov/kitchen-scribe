$:.unshift File.expand_path('../../lib', __FILE__)

require 'chef/knife'
require 'chef/shef/ext'
require 'kitchen_scribe/scribe_hire'
require 'kitchen_scribe/scribe_copy'
