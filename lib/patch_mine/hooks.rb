module PatchMine
  class Hooks < Redmine::Hook::ViewListener
    render_on :view_issues_show_details_bottom,
              :partial => 'hooks/patch_mine/view_issues_show_details_bottom'
    # TODO also embed patch contents / comments into comments list ?
  end
end
