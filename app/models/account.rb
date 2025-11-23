class Account < ApplicationRecord
    has_many :statements, dependent: :destroy
  has_many :trades, dependent: :destroy
  
    validates :number, presence: true
    validates :name, presence: true
  end