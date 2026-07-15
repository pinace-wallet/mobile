/// A wallet account's public metadata. The private key lives only in
/// secure storage under `pinace.key.<uid>.<id>` and is never serialized here.
class WalletAccount {
  const WalletAccount({
    required this.id,
    required this.name,
    required this.address,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String address;
  final DateTime createdAt;

  WalletAccount copyWith({String? name}) => WalletAccount(
        id: id,
        name: name ?? this.name,
        address: address,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory WalletAccount.fromJson(Map<String, dynamic> json) => WalletAccount(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (json['createdAt'] as num?)?.toInt() ?? 0),
      );
}
