class CreateKnowledgeBaseEntries < ActiveRecord::Migration[7.0]
  def change
    create_table :knowledge_base_entries do |t|
      t.references :account, null: false, foreign_key: true
      t.string :level, null: false
      t.text :description, null: false
      t.timestamps
    end
  end
end
