import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uber/util/StatusRequisicao.dart';
class PainelMotorista extends StatefulWidget {

  @override
  _PainelMotoristaState createState() => _PainelMotoristaState();
}

class _PainelMotoristaState extends State<PainelMotorista> {
  List<String> itensMenu = [
    "Configurações", "Deslogar"
  ];
  final _controller = StreamController<QuerySnapshot>.broadcast();
  Firestore db = Firestore.instance;

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

  Stream<QuerySnapshot>_adicionarListenerRequisicoes(){
    final stream = db.collection("requisicoes")
        .where("status", isEqualTo: StatusRequisicao.AGUARDANDO)
        .snapshots();

    stream.listen((dados) {
      _controller.add(dados);
    });
  }

  @override
  void initState() {
    super.initState();

    _adicionarListenerRequisicoes();
  }

  @override
  Widget build(BuildContext context) {
    var mensagemCarregando = Center(
      child: Column(
        children: [
          Text("Carregando requisições"),
          CircularProgressIndicator()
        ],
      ),
    );

    var mensagemNaoTemDados = Center(
      child: Text("Você não tem nenhuma requisição!",style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold
      ),),
    );

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
      body: StreamBuilder<QuerySnapshot>(
        stream: _controller.stream,
        builder: (context, snapshot){
            switch(snapshot.connectionState){
              case ConnectionState.none:

              case ConnectionState.waiting:
                return mensagemCarregando;
                break;
              case ConnectionState.active:

              case ConnectionState.done:
                if(snapshot.hasError){
                    return Text("Erro ao carregar os dados!");
                }else{
                  QuerySnapshot querySnapshot = snapshot.data;
                  if(querySnapshot.documents.length == 0){
                    return mensagemNaoTemDados;
                  }else{
                    return ListView.separated(
                        itemBuilder: (context, indice){
                          List<DocumentSnapshot> requisicoes = querySnapshot.documents.toList();
                          DocumentSnapshot item = requisicoes[indice];

                          String idRequisicao = item["id"];
                          String nomePassageiro = item["passageiro"]["nome"];
                          String rua = item["destino"]["rua"];
                          String numero = item["destino"]["numero"];

                          return ListTile(
                            title: Text(nomePassageiro),
                            subtitle: Text("Destino: $rua, $numero"),
                            onTap: (){
                              Navigator.pushNamed(context, "/corrida", arguments: idRequisicao);
                            },
                          );
                        },
                        separatorBuilder: (context, indice) => Divider(
                          height: 2,
                          color: Colors.grey,
                        ),
                        itemCount: querySnapshot.documents.length
                    );
                  }
                }
                break;
            }
        },
      ),
    );
  }
}
