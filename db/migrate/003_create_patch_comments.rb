class CreatePatchComments < ActiveRecord::Migration
  def self.up
    create_table :patch_comments do |t|
      t.column :patch_id, :integer
      t.column :message_id, :string
      t.column :content, :string
      t.column :resolution, :string
    end
  end

  def self.down
    drop_table :patch_comments
  end
end
