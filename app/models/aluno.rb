# frozen_string_literal: true

class Aluno < ApplicationRecord
  belongs_to :usuario, class_name: "User", inverse_of: :alunos
  has_many :provas, foreign_key: :aluno_ra, primary_key: :ra, dependent: :nullify, inverse_of: :aluno

  before_validation :normalize_ra
  before_validation :normalize_email

  validates :ra, presence: true, format: { with: /\A[A-Z]\d+\z/, message: "use o formato N874321" }
  validates :nome, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :ra, uniqueness: { case_sensitive: false }

  def to_param
    ra
  end

  def display_name
    base = [ ra, nome ].compact.join(" — ")
    email.present? ? "#{base} (#{email})" : base
  end

  private

  def normalize_ra
    self.ra = ra.to_s.strip.upcase.presence
  end

  def normalize_email
    self.email = email.to_s.strip.downcase.presence
  end
end
