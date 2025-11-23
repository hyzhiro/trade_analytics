class Statement < ApplicationRecord
  belongs_to :account
  has_one_attached :file
  has_many :trades, dependent: :destroy

  validates :file, presence: true
end