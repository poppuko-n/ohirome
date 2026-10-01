# <機能の日本語名> 動作確認用データ
# 投入: bin/rails runner docs/verification/<YYYYMMDD>_<機能名>/seed.rb
abort '開発環境でのみ実行できます' unless Rails.env.development?

# ログインユーザー
admin = AdminUser.find_or_create_by!(email: 'sato.kenichi@example.com') do |u|
  u.name = '佐藤 健一'
  u.password = 'password'
end

# 確認に必要なレコード（本番にありそうな固定値で書く）
customer = Customer.find_or_create_by!(email: 'yamada.hanako@example.com') do |c|
  c.name = '山田 花子'
  c.address = '東京都世田谷区桜新町1-2-3'
end

product = Product.find_or_create_by!(name: '春の新作ブレンド 200g') do |p|
  p.price = 1_980
end

order = Order.find_or_create_by!(number: '1024') do |o|
  o.customer = customer
  o.product = product
end
# 手順の中で変える値は、流すたびに手順開始時の状態へ戻す
order.update!(quantity: 2)

puts <<~TEXT
  ■ ログイン情報
    メール:     #{admin.email}
    パスワード: password

  ■ 確認で使う URL
    注文 #1024: http://localhost:3000/admin/orders/#{order.id}/edit
TEXT
