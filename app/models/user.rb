class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :provas, foreign_key: :usuario_id, dependent: :destroy, inverse_of: :usuario
  has_many :alunos, foreign_key: :usuario_id, dependent: :destroy, inverse_of: :usuario

  has_one_attached :avatar, dependent: :purge

  before_validation :normalize_username

  validates :username,
           presence: true,
           length: { maximum: 30 },
           format: { with: /\A[a-zA-Z0-9_.]+\z/, message: "use apenas letras, números, _ ou ." },
           uniqueness: { case_sensitive: false },
           on: :create

  validate :avatar_size
  validate :avatar_content_type

  private

  def normalize_username
    self.username = username.to_s.strip.presence&.downcase
  end

  def avatar_size
    return unless avatar.attached?

    if avatar.blob.byte_size > 5.megabytes
      errors.add(:avatar, "deve ser menor que 5MB")
    end
  end

  def avatar_content_type
    return unless avatar.attached?

    valid_types = [ "image/png", "image/jpeg", "image/gif" ]
    unless valid_types.include?(avatar.blob.content_type)
      errors.add(:avatar, "deve ser PNG, JPG ou GIF")
    end
  end
end
