require 'redmine'

require 'patch_mine/hooks'
require 'patch_mine/issue_patch'

Redmine::Plugin.register :redmine_patch_mine do
  name 'Redmine PatchMine plugin'
  author 'Mo Morsi'
  description 'A plugin for extended Patch integration into redmine'
  version '0.0.1'
  url 'http://github.com/movitto/patchmine'
  author_url 'http://mo.morsi.org'
end
