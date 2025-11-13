# Script para habilitar a feature flag de campanhas WhatsApp em todas as contas
# Uso: rails runner scripts/enable_whatsapp_campaigns.rb
# Ou para uma conta específica: rails runner scripts/enable_whatsapp_campaigns.rb ACCOUNT_ID

account_id = ARGV[0]

if account_id
  # Habilita para uma conta específica
  account = Account.find(account_id)
  puts "Habilitando campanhas WhatsApp para a conta: #{account.name} (ID: #{account.id})"
  account.enable_features!(:whatsapp_campaign)
  puts "✓ Feature flag habilitada com sucesso!"
  puts "  Verificação: #{account.feature_enabled?(:whatsapp_campaign) ? 'Habilitada' : 'Desabilitada'}"
else
  # Habilita para todas as contas
  puts "Habilitando campanhas WhatsApp para todas as contas..."
  Account.find_each do |account|
    account.enable_features!(:whatsapp_campaign)
    puts "✓ Conta #{account.name} (ID: #{account.id}) - Feature flag habilitada"
  end
  puts "\n✓ Todas as contas foram atualizadas!"
end

