
import 'package:flutter/material.dart';

void main() => runApp(const SalgaderiaApp());
String money(double value) => 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

class Product {
  Product(this.id, this.name, this.category, this.price, this.stock, this.description, {this.active = true});
  final int id;
  String name, category, description;
  double price;
  int stock;
  bool active;
}
class OrderLine {
  OrderLine(this.name, this.quantity, this.unitPrice);
  final String name;
  final int quantity;
  final double unitPrice;
  double get total => quantity * unitPrice;
}
class SaleOrder {
  SaleOrder(this.id, this.customer, this.address, this.payment, this.lines, this.total);
  final int id;
  final String customer, address, payment;
  String customerEmail = '';
  final List<OrderLine> lines;
  final double total;
  String status = 'Recebido';
}

class CustomerAccount {
  CustomerAccount(this.name, this.email, this.password);
  final String name, email, password; // Demonstração local; nunca armazenar senhas assim em produção.
}

class Store extends ChangeNotifier {
  final accounts = <CustomerAccount>[];
  CustomerAccount? currentUser;

  String? register(String name, String email, String password) {
    final normalized = email.trim().toLowerCase();
    if (accounts.any((a) => a.email == normalized)) return 'E-mail já cadastrado.';
    if (name.trim().isEmpty || !normalized.contains('@') || password.length < 6) {
      return 'Informe nome, e-mail válido e senha com pelo menos 6 caracteres.';
    }
    final account = CustomerAccount(name.trim(), normalized, password);
    accounts.add(account);
    currentUser = account;
    notifyListeners();
    return null;
  }

  String? login(String email, String password) {
    final normalized = email.trim().toLowerCase();
    for (final account in accounts) {
      if (account.email == normalized && account.password == password) {
        currentUser = account;
        notifyListeners();
        return null;
      }
    }
    return 'E-mail ou senha incorretos.';
  }

  void logout() { currentUser = null; notifyListeners(); }

  final products = <Product>[
    Product(1, 'Coxinha de frango', 'Fritos', 7, 35, 'Massa macia e recheio de frango.'),
    Product(2, 'Pastel de queijo', 'Fritos', 8, 24, 'Queijo derretido e massa crocante.'),
    Product(3, 'Quibe', 'Fritos', 7.5, 18, 'Quibe tradicional.'),
    Product(4, 'Empada de frango', 'Assados', 9, 20, 'Empada artesanal.'),
    Product(5, 'Esfiha de carne', 'Assados', 8.5, 30, 'Esfiha assada.'),
    Product(6, 'Combo festa (20 un.)', 'Combos', 110, 8, 'Vinte salgados variados.'),
  ];
  final cart = <int, int>{};
  final orders = <SaleOrder>[];
  int _nextProduct = 7;
  int _nextOrder = 1;
  Product? find(int id) { for (final p in products) { if (p.id == id) return p; } return null; }
  int quantity(Product p) => cart[p.id] ?? 0;
  int get cartCount => cart.values.fold(0, (a,b) => a+b);
  double get cartTotal => cart.entries.fold(0.0, (a,e) => a+(find(e.key)?.price ?? 0)*e.value);
  void add(Product p) {
    if (!p.active || quantity(p) >= p.stock) return;
    cart[p.id] = quantity(p)+1; notifyListeners();
  }
  void decrease(Product p) {
    final q = quantity(p);
    if (q <= 1) { cart.remove(p.id); } else { cart[p.id] = q-1; }
    notifyListeners();
  }
  void save(Product? old, String name, String category, double price, int stock, String description) {
    if (old == null) {
      products.add(Product(_nextProduct++, name, category, price, stock, description));
    } else {
      old.name=name; old.category=category; old.price=price; old.stock=stock; old.description=description;
      final q = cart[old.id] ?? 0;
      if (q > stock) { if (stock == 0) { cart.remove(old.id); } else { cart[old.id]=stock; } }
    }
    notifyListeners();
  }
  void toggle(Product p) { p.active=!p.active; if (!p.active) cart.remove(p.id); notifyListeners(); }
  String? checkout(String customer, String address, String payment) {
    if (currentUser == null) return 'Faça login para confirmar o pedido.';
    if (cart.isEmpty) return 'Carrinho vazio.';
    for (final e in cart.entries) {
      final p=find(e.key);
      if (p==null || !p.active || p.stock<e.value) return 'Estoque indisponível. Atualize o carrinho.';
    }
    final total = cartTotal;
    final lines=<OrderLine>[];
    for (final e in cart.entries) {
      final p=find(e.key)!;
      lines.add(OrderLine(p.name,e.value,p.price));
      p.stock-=e.value;
    }
    final order = SaleOrder(_nextOrder++,customer,address,payment,lines,total);
    order.customerEmail = currentUser!.email;
    orders.insert(0,order);
    cart.clear(); notifyListeners(); return null;
  }
  void status(SaleOrder order, String value) { order.status=value; notifyListeners(); }
  double get revenue => orders.where((o)=>o.status!='Cancelado').fold(0.0,(a,o)=>a+o.total);
}

class SalgaderiaApp extends StatefulWidget {
  const SalgaderiaApp({super.key});
  @override State<SalgaderiaApp> createState()=>_SalgaderiaAppState();
}
class _SalgaderiaAppState extends State<SalgaderiaApp> {
  final store=Store();
  bool admin=false;
  @override void dispose(){store.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>MaterialApp(
    debugShowCheckedModeBanner:false,
    title:'Sabor & Salgados',
    theme:ThemeData(colorScheme:ColorScheme.fromSeed(seedColor:Colors.deepOrange),useMaterial3:true,
      scaffoldBackgroundColor:const Color(0xfffff9f5)),
    home:AnimatedBuilder(animation:store,builder:(context,_)=>admin
      ? AdminHome(store:store,onExit:()=>setState(()=>admin=false))
      : CustomerHome(store:store,onAdmin:()=>setState(()=>admin=true))),
  );
}
class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key,required this.store,required this.onAdmin});
  final Store store; final VoidCallback onAdmin;
  @override State<CustomerHome> createState()=>_CustomerHomeState();
}
class _CustomerHomeState extends State<CustomerHome> {
  int tab=0; String search=''; String category='Todos';
  @override Widget build(BuildContext context) {
    final s=widget.store;
    final pages=[_catalog(s),_cart(s),_orders(s)];
    return Scaffold(
      appBar:AppBar(title:const Text('🥟 Sabor & Salgados'),actions:[
        IconButton(tooltip:'Área administrativa (demonstração)',onPressed:widget.onAdmin,icon:const Icon(Icons.admin_panel_settings_outlined))
      ]),
      body:pages[tab],
      bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),destinations:[
        const NavigationDestination(icon:Icon(Icons.storefront_outlined),label:'Cardápio'),
        NavigationDestination(icon:Badge(isLabelVisible:s.cartCount>0,label:Text('${s.cartCount}'),child:const Icon(Icons.shopping_cart_outlined)),label:'Carrinho'),
        const NavigationDestination(icon:Icon(Icons.receipt_long_outlined),label:'Pedidos'),
      ]),
    );
  }
  Widget _catalog(Store s) {
    final items=s.products.where((p)=>p.active && (category=='Todos'||p.category==category) &&
      p.name.toLowerCase().contains(search.toLowerCase())).toList();
    return Column(children:[
      Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Feitos com carinho, entregues com sabor!',style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:12),
        TextField(decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Buscar salgados',border:OutlineInputBorder()),onChanged:(v)=>setState(()=>search=v)),
        const SizedBox(height:10),
        SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:['Todos','Fritos','Assados','Combos'].map((c)=>Padding(padding:const EdgeInsets.only(right:8),child:ChoiceChip(label:Text(c),selected:category==c,onSelected:(_)=>setState(()=>category=c)))).toList())),
      ])),
      Expanded(child:items.isEmpty?const Center(child:Text('Nenhum produto encontrado.')):ListView.builder(itemCount:items.length,itemBuilder:(context,i){
        final p=items[i];return Card(margin:const EdgeInsets.symmetric(horizontal:16,vertical:5),child:Padding(padding:const EdgeInsets.all(12),child:Row(children:[
          const CircleAvatar(radius:28,child:Icon(Icons.fastfood)),
          const SizedBox(width:12),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(p.name,style:const TextStyle(fontWeight:FontWeight.bold)),Text(p.description),Text('${money(p.price)} • Estoque: ${p.stock}'),
          ])),
          IconButton(onPressed:p.stock>s.quantity(p)?()=>s.add(p):null,icon:const Icon(Icons.add_circle),tooltip:'Adicionar'),
        ])));
      }))
    ]);
  }
  Widget _cart(Store s) {
    final entries=s.cart.entries.toList();
    return Column(children:[
      Expanded(child:entries.isEmpty?const Center(child:Text('Seu carrinho está vazio.')):ListView(children:entries.map((e){
        final p=s.find(e.key)!;
        return Card(margin:const EdgeInsets.symmetric(horizontal:16,vertical:5),child:ListTile(title:Text(p.name),subtitle:Text('${money(p.price)} × ${e.value} = ${money(p.price*e.value)}'),
          trailing:Wrap(crossAxisAlignment:WrapCrossAlignment.center,children:[
            IconButton(onPressed:()=>s.decrease(p),icon:const Icon(Icons.remove_circle_outline)),
            Text('${e.value}'),
            IconButton(onPressed:e.value<p.stock?()=>s.add(p):null,icon:const Icon(Icons.add_circle_outline)),
          ])));
      }).toList())),
      Padding(padding:const EdgeInsets.all(16),child:Column(children:[
        Text('Total: ${money(s.cartTotal)}',style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:8),
        FilledButton.icon(onPressed:entries.isEmpty?null:()=>_checkout(s),icon:const Icon(Icons.check_circle_outline),label:const Text('Finalizar pedido')),
      ]))
    ]);
  }
  Future<void> _checkout(Store s) async {
    if (s.currentUser == null) {
      final authenticated = await showDialog<bool>(
        context: context,
        builder: (_) => CustomerAuthDialog(store: s),
      );
      if (!mounted || authenticated != true) return;
    }
    final form=GlobalKey<FormState>(); final name=TextEditingController(text:s.currentUser?.name ?? '');final address=TextEditingController();
    String payment='Pix';
    await showDialog<void>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(context,refresh)=>AlertDialog(
      title:const Text('Finalizar pedido'),
      content:SingleChildScrollView(child:Form(key:form,child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextFormField(controller:name,decoration:const InputDecoration(labelText:'Nome do cliente'),validator:(v)=>v==null||v.trim().isEmpty?'Informe seu nome':null),
        TextFormField(controller:address,decoration:const InputDecoration(labelText:'Endereço ou retirada'),validator:(v)=>v==null||v.trim().isEmpty?'Informe entrega ou retirada':null),
        DropdownButtonFormField<String>(initialValue:payment,decoration:const InputDecoration(labelText:'Forma de pagamento'),items:['Pix','Dinheiro na entrega','Cartão na entrega'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>refresh(()=>payment=v!)),
        const SizedBox(height:12),Text('Total: ${money(s.cartTotal)}'),
        const Text('Pagamento apenas simulado; não há cobrança online.',style:TextStyle(fontSize:12)),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Voltar')),
        FilledButton(onPressed:(){
          if(!form.currentState!.validate())return;
          final error=s.checkout(name.text.trim(),address.text.trim(),payment);
          Navigator.pop(dialogContext);
          if(mounted){ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content:Text(error??'Pedido realizado com sucesso!')));if(error==null)setState(()=>tab=2);}
        },child:const Text('Confirmar'))],
    )));
    name.dispose();address.dispose();
  }
  Widget _orders(Store s) {
    final mine = s.currentUser == null ? <SaleOrder>[] : s.orders.where((o)=>o.customerEmail==s.currentUser!.email).toList();
    return Column(children:[Padding(padding:const EdgeInsets.all(12),child:Row(children:[Expanded(child:Text(s.currentUser==null?'Entre para consultar seus pedidos':'Conta: ${s.currentUser!.email}')),TextButton(onPressed:()=>showDialog<bool>(context:context,builder:(_)=>CustomerAuthDialog(store:s)),child:Text(s.currentUser==null?'Entrar / Cadastrar':'Trocar conta')),if(s.currentUser!=null)TextButton(onPressed:s.logout,child:const Text('Sair'))])),Expanded(child:mine.isEmpty?const Center(child:Text('Nenhum pedido para esta conta.')):ListView(children:mine.map((o)=>Card(margin:const EdgeInsets.all(10),child:ExpansionTile(
    title:Text('Pedido #${o.id} • ${money(o.total)}'),subtitle:Text('${o.customer} • ${o.status}'),
    children:[...o.lines.map((l)=>ListTile(title:Text(l.name),trailing:Text('${l.quantity} × ${money(l.unitPrice)}'))),
      ListTile(title:Text('Entrega: ${o.address}'),subtitle:Text('Pagamento: ${o.payment}'))],
  ))).toList()))]);
  }
}


class CustomerAuthDialog extends StatefulWidget {
  const CustomerAuthDialog({super.key, required this.store});
  final Store store;
  @override State<CustomerAuthDialog> createState() => _CustomerAuthDialogState();
}
class _CustomerAuthDialogState extends State<CustomerAuthDialog> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool registering = false;
  bool obscure = true;
  String? error;
  @override void dispose() {
    name.dispose(); email.dispose(); password.dispose(); super.dispose();
  }
  void submit() {
    if (!formKey.currentState!.validate()) return;
    final result = registering
      ? widget.store.register(name.text, email.text, password.text)
      : widget.store.login(email.text, password.text);
    if (result != null) { setState(() => error = result); return; }
    Navigator.of(context).pop(true);
  }
  @override Widget build(BuildContext context) => AlertDialog(
    title: Text(registering ? 'Criar minha conta' : 'Entrar para finalizar'),
    content: SizedBox(width: 380,child:SingleChildScrollView(child:Form(key:formKey,child:Column(
      mainAxisSize:MainAxisSize.min,children:[
        if(registering) TextFormField(controller:name,decoration:const InputDecoration(labelText:'Nome completo'),
          validator:(v)=>v==null||v.trim().isEmpty?'Informe seu nome':null),
        TextFormField(controller:email,keyboardType:TextInputType.emailAddress,
          decoration:const InputDecoration(labelText:'E-mail'),
          validator:(v)=>v==null||!v.contains('@')?'Informe um e-mail válido':null),
        TextFormField(controller:password,obscureText:obscure,
          decoration:InputDecoration(labelText:'Senha',suffixIcon:IconButton(
            onPressed:()=>setState(()=>obscure=!obscure),
            icon:Icon(obscure?Icons.visibility:Icons.visibility_off))),
          validator:(v)=>v==null||v.length<6?'Mínimo de 6 caracteres':null),
        if(error!=null) Padding(padding:const EdgeInsets.only(top:8),child:Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
        TextButton(onPressed:()=>setState(() {registering=!registering;error=null;}),
          child:Text(registering?'Já tenho conta: entrar':'Não tenho conta: cadastrar')),
        const Text('Demonstração: contas e senhas ficam somente na memória deste aplicativo.',style:TextStyle(fontSize:12)),
      ])))),
    actions:[
      TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancelar')),
      FilledButton(onPressed:submit,child:Text(registering?'Cadastrar e continuar':'Entrar e continuar')),
    ],
  );
}

class AdminHome extends StatefulWidget {
  const AdminHome({super.key,required this.store,required this.onExit});
  final Store store;final VoidCallback onExit;
  @override State<AdminHome> createState()=>_AdminHomeState();
}
class _AdminHomeState extends State<AdminHome> {
  int tab=0;
  @override Widget build(BuildContext context){
    final s=widget.store;
    return Scaffold(appBar:AppBar(title:const Text('Painel administrativo'),actions:[IconButton(onPressed:widget.onExit,tooltip:'Voltar à loja',icon:const Icon(Icons.logout))]),
      body:[_dashboard(s),_products(s),_orders(s)][tab],
      floatingActionButton:tab==1?FloatingActionButton.extended(onPressed:()=>_edit(s,null),icon:const Icon(Icons.add),label:const Text('Produto')):null,
      bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),destinations:const [
        NavigationDestination(icon:Icon(Icons.dashboard_outlined),label:'Resumo'),
        NavigationDestination(icon:Icon(Icons.inventory_2_outlined),label:'Produtos'),
        NavigationDestination(icon:Icon(Icons.receipt_long_outlined),label:'Pedidos'),
      ]));
  }
  Widget _dashboard(Store s)=>ListView(padding:const EdgeInsets.all(16),children:[
    Text('Visão geral',style:Theme.of(context).textTheme.headlineSmall),
    _metric('Faturamento (exceto cancelados)',money(s.revenue),Icons.payments_outlined),
    _metric('Pedidos registrados','${s.orders.length}',Icons.receipt_outlined),
    _metric('Produtos ativos','${s.products.where((p)=>p.active).length}',Icons.inventory_outlined),
    _metric('Pedidos em andamento','${s.orders.where((o)=>!['Entregue','Cancelado'].contains(o.status)).length}',Icons.local_shipping_outlined),
    const SizedBox(height:16),const Text('Indicadores demonstrativos: dados somente em memória.'),
  ]);
  Widget _metric(String label,String value,IconData icon)=>Card(child:ListTile(leading:Icon(icon),title:Text(label),subtitle:Text(value,style:Theme.of(context).textTheme.titleLarge)));
  Widget _products(Store s)=>ListView(padding:const EdgeInsets.only(bottom:90),children:s.products.map((p)=>Card(margin:const EdgeInsets.symmetric(horizontal:12,vertical:5),child:ListTile(
    title:Text(p.name),subtitle:Text('${p.category} • ${money(p.price)} • Estoque: ${p.stock}\n${p.active?'Ativo':'Inativo'}'),
    isThreeLine:true,
    trailing:Wrap(children:[
      IconButton(tooltip:'Editar',onPressed:()=>_edit(s,p),icon:const Icon(Icons.edit_outlined)),
      IconButton(tooltip:p.active?'Desativar':'Ativar',onPressed:()=>s.toggle(p),icon:Icon(p.active?Icons.visibility_off_outlined:Icons.visibility_outlined)),
    ]),
  ))).toList());
  Future<void> _edit(Store s,Product? p) async {
    final key=GlobalKey<FormState>();
    final name=TextEditingController(text:p?.name??'');
    final category=TextEditingController(text:p?.category??'Fritos');
    final price=TextEditingController(text:p?.price.toString()??'');
    final stock=TextEditingController(text:p?.stock.toString()??'');
    final description=TextEditingController(text:p?.description??'');
    await showDialog<void>(context:context,builder:(dialogContext)=>AlertDialog(
      title:Text(p==null?'Novo produto':'Editar produto'),
      content:SingleChildScrollView(child:SizedBox(width:420,child:Form(key:key,child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextFormField(controller:name,decoration:const InputDecoration(labelText:'Nome'),validator:(v)=>v==null||v.trim().isEmpty?'Obrigatório':null),
        TextFormField(controller:category,decoration:const InputDecoration(labelText:'Categoria'),validator:(v)=>v==null||v.trim().isEmpty?'Obrigatório':null),
        TextFormField(controller:price,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Preço (ex.: 7,50)'),validator:(v){final n=double.tryParse((v??'').replaceAll(',','.'));return n==null||n<=0?'Preço inválido':null;}),
        TextFormField(controller:stock,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Estoque'),validator:(v){final n=int.tryParse(v??'');return n==null||n<0?'Estoque inválido':null;}),
        TextFormField(controller:description,decoration:const InputDecoration(labelText:'Descrição'),maxLines:2),
      ])))),
      actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Cancelar')),
        FilledButton(onPressed:(){if(!key.currentState!.validate())return;s.save(p,name.text.trim(),category.text.trim(),double.parse(price.text.replaceAll(',','.')),int.parse(stock.text),description.text.trim());Navigator.pop(dialogContext);},child:const Text('Salvar'))],
    ));
    name.dispose();category.dispose();price.dispose();stock.dispose();description.dispose();
  }
  Widget _orders(Store s)=>s.orders.isEmpty?const Center(child:Text('Nenhum pedido recebido.')):ListView(children:s.orders.map((o)=>Card(margin:const EdgeInsets.all(10),child:ExpansionTile(
    title:Text('Pedido #${o.id} • ${money(o.total)}'),subtitle:Text('${o.customer} • ${o.status}'),
    children:[...o.lines.map((l)=>ListTile(title:Text(l.name),trailing:Text('${l.quantity} × ${money(l.unitPrice)}'))),
      ListTile(title:Text(o.address),subtitle:Text('Pagamento: ${o.payment}')),
      Padding(padding:const EdgeInsets.all(12),child:DropdownButtonFormField<String>(key:ValueKey('${o.id}-${o.status}'),initialValue:o.status,decoration:const InputDecoration(labelText:'Situação do pedido',border:OutlineInputBorder()),
        items:['Recebido','Em preparo','Saiu para entrega','Entregue','Cancelado'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),
        onChanged:(v){if(v!=null)s.status(o,v);})),
    ],
  ))).toList());
}
