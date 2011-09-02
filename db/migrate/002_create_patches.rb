class CreatePatches < ActiveRecord::Migration
  def self.up
    create_table :patches do |t|
      t.column :issue_id,   :integer
      t.column :mailing_list_id, :integer
      t.column :patch_id, :integer
      t.column :message_id, :string
      t.column :subject,    :string
      t.column :content,    :string
    end
  end

  def self.down
    drop_table :patches
  end
end
