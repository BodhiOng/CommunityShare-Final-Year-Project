import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'constants.dart';
import 'buyer_home_page.dart';
import 'buyer_purchases_page.dart';
import 'buyer_profile_page.dart';
import 'utils/page_transitions.dart';

class MyWalletPage extends StatefulWidget {
  const MyWalletPage({super.key});

  @override
  State<MyWalletPage> createState() => _MyWalletPageState();
}

class _MyWalletPageState extends State<MyWalletPage> {
  int _selectedIndex = 2; // Set to 2 for Wallet tab
  double _balance = 0.0; // Will be fetched from Firestore
  bool _isLoading = true;
  
  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _uid = '';
  
  // Transaction history
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoadingTransactions = true;

  @override
  void initState() {
    super.initState();
    _fetchWalletData();
  }
  
  // Fetch wallet data and transaction history from Firestore
  Future<void> _fetchWalletData() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
          _isLoadingTransactions = false;
        });
        return;
      }

      _uid = currentUser.uid;
      
      // Fetch user wallet balance
      final DocumentSnapshot userDoc = 
          await _firestore.collection('users').doc(_uid).get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;

        setState(() {
          _balance = (userData['walletBalance'] ?? 0.0).toDouble();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
      
      // Fetch transaction history
      await _fetchTransactionHistory();
      
    } catch (e) {
      debugPrint('Error fetching wallet data: $e');
      setState(() {
        _isLoading = false;
        _isLoadingTransactions = false;
      });
    }
  }
  
  // Fetch transaction history from Firestore
  Future<void> _fetchTransactionHistory() async {
    try {
      setState(() {
        _isLoadingTransactions = true;
      });
      
      final QuerySnapshot transactionSnapshot = await _firestore
          .collection('walletTransactions')
          .where('userId', isEqualTo: _uid)
          .orderBy('timestamp', descending: true)
          .get();
          
      List<Map<String, dynamic>> transactions = [];
      
      for (var doc in transactionSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Convert Firestore data to app format
        transactions.add({
          'id': doc.id,
          'type': data['type'] ?? '',
          'description': data['description'] ?? '',
          'amount': _getTransactionAmount(data['type'] as String, (data['amount'] ?? 0).toDouble()),
          'date': (data['timestamp'] as Timestamp).toDate(),
          'relatedOrderId': data['relatedOrderId'],
        });
      }
      
      setState(() {
        _transactions = transactions;
        _isLoadingTransactions = false;
      });
    } catch (e) {
      debugPrint('Error fetching transaction history: $e');
      setState(() {
        _isLoadingTransactions = false;
      });
    }
  }
  
  // Helper to determine transaction amount sign based on type
  double _getTransactionAmount(String type, double amount) {
    switch (type) {
      case 'Deposit':
      case 'Sale':
        return amount.abs(); // Positive
      case 'Withdrawal':
      case 'Purchase':
        return -amount.abs(); // Negative
      default:
        return amount;
    }
  }

  void _onItemTapped(int index) {
    if (index == 0) {
      // Navigate directly to HomePage
      Navigator.pushReplacement(
        context,
        DarkPageReplaceRoute(page: const MyHomePage(title: 'Secondhand Marketplace')),
      );
    } else if (index == 1) {
      // Navigate to My Purchases page
      Navigator.pushReplacement(
        context,
        DarkPageReplaceRoute(page: const MyPurchasesPage()),
      );
    } else if (index == 2) {
      // Already on Wallet page, just update index
      setState(() {
        _selectedIndex = index;
      });
    } else if (index == 3) {
      // Navigate to Profile page
      Navigator.pushReplacement(
        context,
        DarkPageReplaceRoute(page: const MyProfilePage()),
      );
    }
  }

  // Show top-up dialog
  void _showTopUpDialog() {
    final amountController = TextEditingController();
    String selectedPaymentMethod = 'Credit/Debit Card'; // Default payment method

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.deepSlateGray,
              title: Text(
                'Top Up Balance',
                style: TextStyle(color: AppColors.coolGray),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Amount to add:',
                      style: TextStyle(color: AppColors.coolGray),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: AppColors.coolGray),
                      decoration: InputDecoration(
                        prefixText: r'RM',
                        prefixStyle: TextStyle(color: AppColors.coolGray),
                        hintText: '0.00',
                        hintStyle: TextStyle(color: AppColors.coolGray.withAlpha(150)),
                        filled: true,
                        fillColor: AppColors.charcoalBlack,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.coolGray),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.mutedTeal),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Payment Method:',
                      style: TextStyle(color: AppColors.coolGray),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.charcoalBlack,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.coolGray),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedPaymentMethod,
                          dropdownColor: AppColors.charcoalBlack,
                          style: TextStyle(color: AppColors.coolGray),
                          icon: Icon(Icons.arrow_drop_down, color: AppColors.coolGray),
                          items: [
                            'Credit/Debit Card',
                            'E-Wallet',
                            'PayPal',
                          ].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setDialogState(() {
                                selectedPaymentMethod = newValue;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.coolGray),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Validate amount
                    final amountText = amountController.text.trim();
                    if (amountText.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Please enter an amount'),
                          backgroundColor: AppColors.warmCoral,
                        ),
                      );
                      return;
                    }

                    final amount = double.tryParse(amountText);
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Please enter a valid amount'),
                          backgroundColor: AppColors.warmCoral,
                        ),
                      );
                      return;
                    }

                    // Update balance in Firestore
                    _firestore.collection('users').doc(_uid).update({
                      'walletBalance': FieldValue.increment(amount),
                    }).then((_) {
                      // Update local balance
                      setState(() {
                        _balance += amount;
                      });

                      // Add transaction to Firestore
                      final timestamp = Timestamp.now();
                      final transactionId = 'transaction_${DateTime.now().millisecondsSinceEpoch}';
                      
                      // Get description based on payment method
                      String description;
                      switch (selectedPaymentMethod) {
                        case 'Credit/Debit Card':
                          description = 'Card payment to wallet';
                          break;
                        case 'E-Wallet':
                          description = 'E-Wallet transfer to account';
                          break;
                        case 'PayPal':
                          description = 'PayPal deposit to wallet';
                          break;
                        default:
                          description = 'Added via $selectedPaymentMethod';
                      }
                      
                      _firestore.collection('walletTransactions').doc(transactionId).set({
                        'id': transactionId,
                        'userId': _uid,
                        'type': 'Deposit',
                        'amount': amount,
                        'description': description,
                        'timestamp': timestamp,
                        'relatedOrderId': null,
                      });
                      
                      // Refresh transaction history and show success message
                      if (!mounted) return;
                      final currentContext = context;
                      _fetchTransactionHistory().then((_) {
                        if (!mounted) return;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            ScaffoldMessenger.of(currentContext).showSnackBar(
                              SnackBar(
                                content: Text('RM${amount.toStringAsFixed(2)} added to your wallet'),
                                backgroundColor: AppColors.mutedTeal,
                              ),
                            );
                          }
                        });
                      });
                    }).catchError((error) {
                      if (!mounted) return;
                      final errorContext = context;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          ScaffoldMessenger.of(errorContext).showSnackBar(
                            SnackBar(
                              content: Text('Error: $error'),
                              backgroundColor: AppColors.warmCoral,
                            ),
                          );
                        }
                      });
                    });

                    Navigator.pop(context);
                  },
                  child: Text(
                    'Add',
                    style: TextStyle(color: AppColors.mutedTeal),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Show withdraw dialog
  void _showWithdrawDialog() {
    final amountController = TextEditingController();
    String selectedPaymentMethod = 'Credit/Debit Card'; // Default payment method

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.deepSlateGray,
              title: Text(
                'Withdraw Balance',
                style: TextStyle(color: AppColors.coolGray),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Amount to withdraw:',
                      style: TextStyle(color: AppColors.coolGray),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: AppColors.coolGray),
                      decoration: InputDecoration(
                        prefixText: r'RM',
                        prefixStyle: TextStyle(color: AppColors.coolGray),
                        hintText: '0.00',
                        hintStyle: TextStyle(color: AppColors.coolGray.withAlpha(150)),
                        filled: true,
                        fillColor: AppColors.charcoalBlack,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.coolGray),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.mutedTeal),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Withdrawal Method:',
                      style: TextStyle(color: AppColors.coolGray),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.charcoalBlack,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.coolGray),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedPaymentMethod,
                          dropdownColor: AppColors.charcoalBlack,
                          style: TextStyle(color: AppColors.coolGray),
                          icon: Icon(Icons.arrow_drop_down, color: AppColors.coolGray),
                          items: [
                            'Credit/Debit Card',
                            'E-Wallet',
                            'PayPal',
                          ].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setDialogState(() {
                                selectedPaymentMethod = newValue;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.coolGray),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Validate amount
                    final amountText = amountController.text.trim();
                    if (amountText.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Please enter an amount'),
                          backgroundColor: AppColors.warmCoral,
                        ),
                      );
                      return;
                    }

                    final amount = double.tryParse(amountText);
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Please enter a valid amount'),
                          backgroundColor: AppColors.warmCoral,
                        ),
                      );
                      return;
                    }

                    if (amount > _balance) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Insufficient balance'),
                          backgroundColor: AppColors.warmCoral,
                        ),
                      );
                      return;
                    }

                    // Update balance in Firestore
                    _firestore.collection('users').doc(_uid).update({
                      'walletBalance': FieldValue.increment(-amount),
                    }).then((_) {
                      // Update local balance
                      setState(() {
                        _balance -= amount;
                      });

                      // Add transaction to Firestore
                      final timestamp = Timestamp.now();
                      final transactionId = 'transaction_${DateTime.now().millisecondsSinceEpoch}';
                      
                      // Get description based on payment method
                      String description;
                      switch (selectedPaymentMethod) {
                        case 'Credit/Debit Card':
                          description = 'Withdrawal to bank card';
                          break;
                        case 'E-Wallet':
                          description = 'Transfer to e-wallet account';
                          break;
                        case 'PayPal':
                          description = 'Withdrawal to PayPal account';
                          break;
                        default:
                          description = 'Withdrawal via $selectedPaymentMethod';
                      }
                      
                      _firestore.collection('walletTransactions').doc(transactionId).set({
                        'id': transactionId,
                        'userId': _uid,
                        'type': 'Withdrawal',
                        'amount': amount,
                        'description': description,
                        'timestamp': timestamp,
                        'relatedOrderId': null,
                      });
                      
                      // Refresh transaction history and show success message
                      if (!mounted) return;
                      final currentContext = context;
                      _fetchTransactionHistory().then((_) {
                        if (!mounted) return;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            ScaffoldMessenger.of(currentContext).showSnackBar(
                              SnackBar(
                                content: Text('RM${amount.toStringAsFixed(2)} withdrawn from your wallet'),
                                backgroundColor: AppColors.mutedTeal,
                              ),
                            );
                          }
                        });
                      });
                    }).catchError((error) {
                      if (!mounted) return;
                      final errorContext = context;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          ScaffoldMessenger.of(errorContext).showSnackBar(
                            SnackBar(
                              content: Text('Error: $error'),
                              backgroundColor: AppColors.warmCoral,
                            ),
                          );
                        }
                      });
                    });

                    Navigator.pop(context);
                  },
                  child: Text(
                    'Withdraw',
                    style: TextStyle(color: AppColors.mutedTeal),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Helper method to format date
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  // Helper to get transaction icon based on type
  IconData _getTransactionIcon(String type) {
    switch (type) {
      case 'Deposit':
        return Icons.arrow_downward;
      case 'Withdrawal':
        return Icons.arrow_upward;
      case 'Purchase':
        return Icons.shopping_cart;
      case 'Sale':
        return Icons.sell;
      default:
        return Icons.swap_horiz;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoalBlack,
      appBar: AppBar(
        backgroundColor: AppColors.deepSlateGray,
        title: Text(
          'My Wallet',
          style: TextStyle(color: AppColors.coolGray),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Balance card
                    Card(
                      color: AppColors.deepSlateGray,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            // Wallet icon
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: AppColors.mutedTeal.withAlpha(50),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.account_balance_wallet,
                                color: AppColors.mutedTeal,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Balance text
                            Text(
                              'Your Current Balance',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.coolGray,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'RM ${_balance.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Action buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Top up button
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _showTopUpDialog,
                                    icon: const Icon(Icons.add, color: Colors.white),
                                    label: const Text(
                                      'Top Up',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.mutedTeal,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Withdraw button
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _showWithdrawDialog,
                                    icon: const Icon(Icons.arrow_upward, color: Colors.white),
                                    label: const Text(
                                      'Withdraw',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.warmCoral,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Transaction history section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Transaction History',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.coolGray,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.refresh, color: AppColors.coolGray),
                          onPressed: _fetchTransactionHistory,
                          tooltip: 'Refresh transactions',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _isLoadingTransactions
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : _transactions.isEmpty
                        ? Card(
                            color: AppColors.deepSlateGray,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.receipt_long,
                                      color: AppColors.coolGray.withAlpha(150),
                                      size: 48,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No transactions yet',
                                      style: TextStyle(
                                        color: AppColors.coolGray,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : Card(
                            color: AppColors.deepSlateGray,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _transactions.length,
                              separatorBuilder: (context, index) => Divider(
                                color: AppColors.coolGray.withAlpha(50),
                                height: 1,
                              ),
                              itemBuilder: (context, index) {
                                final transaction = _transactions[index];
                                final amount = transaction['amount'] as double;
                                final isPositive = amount > 0;
                                
                                return ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: (isPositive ? AppColors.mutedTeal : AppColors.warmCoral).withAlpha(50),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getTransactionIcon(transaction['type'] as String),
                                      color: isPositive ? AppColors.mutedTeal : AppColors.warmCoral,
                                      size: 20,
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Text(
                                        transaction['type'] as String,
                                        style: TextStyle(color: AppColors.coolGray),
                                      ),
                                      const SizedBox(width: 8),

                                    ],
                                  ),
                                  subtitle: Text(
                                    transaction['description'] as String,
                                    style: TextStyle(color: AppColors.coolGray.withAlpha(150)),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${isPositive ? '+' : ''}RM ${amount.abs().toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: isPositive ? AppColors.mutedTeal : AppColors.warmCoral,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        _formatDate(transaction['date'] as DateTime),
                                        style: TextStyle(
                                          color: AppColors.coolGray.withAlpha(150),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: transaction['relatedOrderId'] != null
                                    ? () {
                                        // Navigate to order details if there's a related order
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Order ID: ${transaction['relatedOrderId']}'),
                                            backgroundColor: AppColors.deepSlateGray,
                                          ),
                                        );
                                      }
                                    : null,
                                );
                              },
                            ),
                          ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag_outlined),
            label: 'My Purchases',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Wallet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        backgroundColor: AppColors.deepSlateGray,
        selectedItemColor: AppColors.softLemonYellow,
        unselectedItemColor: AppColors.coolGray,
        showUnselectedLabels: true,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
