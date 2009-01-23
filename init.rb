# Include hook code here
#require 'google/mapper'
#require 'action_controller/routing'
require_library_or_gem "bluecloth"

ActionController::Base.send :include, ActsAsAdminable::ActionControllerExtension
ActionView::Base.send :include, ActsAsAdminable::Helper
ActionController::Routing::RouteSet::Mapper.send :include, ActsAsAdminable::MapperExtensions

#String.send :include, Google::String