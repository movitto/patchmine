class PatchesController < ApplicationController
  unloadable


  def index
    @issue = Issue.find @params[:issue_id]
    @patches = Patch.find_by_issue_id @issue.id
  end

  def show
    @patch = Patch.find(@params[:id])
  end

end
