import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:google_maps_flutter/google_maps_flutter.dart';

class PainelPassageiro extends StatefulWidget {

  @override
  _PainelPassageiroState createState() => _PainelPassageiroState();
}

class _PainelPassageiroState extends State<PainelPassageiro> {
  List<String> itensMenu = [
    "Configurações", "Deslogar"
  ];
  Completer<GoogleMapController> _controller = Completer();

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

  _onMapCreated(GoogleMapController controller){
    _controller.complete(controller);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Painel passageiro"),
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
      body: Container(
        child: GoogleMap(
          mapType: MapType.normal,
          initialCameraPosition: CameraPosition(
            target: LatLng(-23.563999, -46.653256),
            zoom: 16
          ),
          onMapCreated: _onMapCreated,
        ),
      ),
    );
  }
}
