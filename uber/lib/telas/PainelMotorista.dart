import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
class PainelMotorista extends StatefulWidget {

  @override
  _PainelMotoristaState createState() => _PainelMotoristaState();
}

class _PainelMotoristaState extends State<PainelMotorista> {
  List<String> itensMenu = [
    "Configurações", "Deslogar"
  ];
  _escolhaMenuItem(String escolha){
    switch(escolha){
      case "Deslogar":
        _deslogarUsuario();
        break;
      case "Configurações":
        break;
    }
  }

  _deslogarUsuario() async{
    FirebaseAuth auth =  FirebaseAuth.instance;
    auth.signOut();
    Navigator.pushReplacementNamed(context, "/");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Painel motorista"),
        actions: [
          PopupMenuButton(
            itemBuilder: (context){

              return itensMenu.map((String item){
                return PopupMenuItem(
                  value: item,
                  child: Text(item),
                );
              }).toList();
            },
            onSelected: _escolhaMenuItem,
          )
        ],
      ),
      body: Container(),
    );
  }
}
