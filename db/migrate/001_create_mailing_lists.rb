class CreateMailingLists < ActiveRecord::Migration
  def self.up
    create_table :mailing_lists do |t|
      t.column :name, :string
      t.column :address, :string
    end
  end

  def self.down
    drop_table :mailing_lists
  end
end
