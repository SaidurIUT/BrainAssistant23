# == Schema Information
#
# Table name: knowledge_base_entries
#
#  id          :bigint           not null, primary key
#  account_id  :bigint           not null
#  level       :string           not null
#  description :text             not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

class KnowledgeBaseEntry < ApplicationRecord
  belongs_to :account

  validates :level, presence: true
  validates :description, presence: true
end
