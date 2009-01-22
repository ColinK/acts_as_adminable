# Include hook code here
#require 'google/mapper'
#require 'action_controller/routing'
require_library_or_gem "bluecloth"

#This one saves us from having double-entries in the globalize_translations table for every phrase that gets auto-translated
#Globalize::DbViewTranslator.send :include, Google::LocalizeCacheAccess

ActionController::Routing::RouteSet::Mapper.send :include, ActsAsAdminable::MapperExtensions
ActionView::Helpers::TagHelper.send :include, ActsAsAdminable::Helper

#String.send :include, Google::String