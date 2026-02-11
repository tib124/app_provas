class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :provas, foreign_key: :usuario_id, dependent: :destroy, inverse_of: :usuario
  has_many :alunos, foreign_key: :usuario_id, dependent: :destroy, inverse_of: :usuario

  before_validation :normalize_username

  validates :username,
           presence: true,
           length: { maximum: 30 },
           format: { with: /\A[a-zA-Z0-9_.]+\z/, message: "use apenas letras, números, _ ou ." },
           uniqueness: { case_sensitive: false },
           on: :create

  private

  def normalize_username
    self.username = username.to_s.strip.presence&.downcase
  end
end
