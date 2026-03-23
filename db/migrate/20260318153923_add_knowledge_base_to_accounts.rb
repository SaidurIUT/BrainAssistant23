class AddKnowledgeBaseToAccounts < ActiveRecord::Migration[7.0]
  def change
    add_column :accounts, :website_url, :string
    add_column :accounts, :scraped_data, :text
  end
end
