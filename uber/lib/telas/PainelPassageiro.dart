import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uber/model/Destino.dart';

class PainelPassageiro extends StatefulWidget {

  @override
  _PainelPassageiroState createState() => _PainelPassageiroState();
}

class _PainelPassageiroState extends State<PainelPassageiro> {
  TextEditingController _controllerDestino = TextEditingController(text:"Av Paulista, 342");
  List<String> itensMenu = [
    "Configurações", "Deslogar"
  ];
  Completer<GoogleMapController> _controller = Completer();

  CameraPosition _posicaoCamera = CameraPosition(
      target: LatLng(-23.563999, -46.653256),

  );

  Set<Marker> _marcadores ={};

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

  _adicionarListenerLocalizacao(){
    var geolocator = Geolocator();
    var locationOptions = LocationOptions(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10
    );
    geolocator.getPositionStream(locationOptions).listen((position) {
      _exibirMarcadorPassageiro(position);
      _posicaoCamera = CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 19
      );
      _movimentarCamera(_posicaoCamera);
    });
  }

  _recuperarUltimaLocalizacaoConhecida() async{
    Position position = await Geolocator()
        .getLastKnownPosition(desiredAccuracy: LocationAccuracy.high);

    setState(() {
      if(position != null){
        _exibirMarcadorPassageiro(position);
        _posicaoCamera = CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 19
        );
        _movimentarCamera(_posicaoCamera);
      }
    });
  }

  _movimentarCamera(CameraPosition cameraPosition) async{
    GoogleMapController googleMapController = await _controller.future;
    googleMapController.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }
  
  _exibirMarcadorPassageiro( Position local) async{
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;
    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        "imagens/passageiro.png").then((icone){

      Marker marcadorPassageiro = Marker(
          markerId: MarkerId("marcador-passageiro"),
          position: LatLng(local.latitude, local.longitude),
          infoWindow: InfoWindow(
              title: "Meu local"
          ),
          icon: icone
      );
      
      setState(() {
        _marcadores.add(marcadorPassageiro);
      });
    });

  }

  _chamarUber() async{
    String enderecoDestino = _controllerDestino.text;
    if(enderecoDestino.isNotEmpty){
      List<Placemark> listaEnderecos = await Geolocator()
          .placemarkFromAddress(enderecoDestino);
      if(listaEnderecos != null && listaEnderecos.length > 0){
        Placemark endereco = listaEnderecos[0];
        Destino destino = Destino();
        destino.cidade = endereco.administrativeArea;
        destino.cep = endereco.postalCode;
        destino.bairro = endereco.subLocality;
        destino.rua = endereco.thoroughfare;
        destino.numero = endereco.subThoroughfare;
        destino.latitude = endereco.position.latitude;
        destino.longitude = endereco.position.longitude;

        String enderecoConfirmacao;
        enderecoConfirmacao = "\n Cidade: "+ destino.cidade;
        enderecoConfirmacao+= "\n Rua: "+ destino.rua + ", "+destino.numero;
        enderecoConfirmacao+= "\n Bairro: "+ destino.bairro;
        enderecoConfirmacao+= "\n Cep: "+ destino.cep;
        
        showDialog(
            context: context,
            builder: (context){
              return AlertDialog(
                title: Text("Confirmação do endereço"),
                content:  Text(enderecoConfirmacao),
                contentPadding: EdgeInsets.all(16),
                actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("Cancelar", style: TextStyle(color: Colors.red),)),
                    TextButton(
                      onPressed: () {
                        // _salvarRequisicao();
                        Navigator.pop(context);
                      },
                      child: Text("Confirmar", style: TextStyle(color: Colors.red),)),
                ],
              );
            });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _recuperarUltimaLocalizacaoConhecida();
    _adicionarListenerLocalizacao();
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
        child: Stack(
          children: [
            GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: _posicaoCamera,
              onMapCreated: _onMapCreated,
              //myLocationEnabled: true,
              myLocationButtonEnabled: false,
              markers: _marcadores,
            ),
            Positioned(
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Container(
                    height: 50,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(3),
                      color: Colors.white
                    ),
                    child: TextField(
                      readOnly: true,
                      decoration: InputDecoration(
                        icon: Container(
                          margin: EdgeInsets.only(left: 20),
                          width: 10,
                          height: 10,
                          child: Icon(Icons.location_on, color: Colors.green,),
                        ),
                        hintText: "Meu local",
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.only(left: 15, top: 16)
                      ),
                    ),
                  ),
                )
            ),
            Positioned(
              top: 55,
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Container(
                    height: 50,
                    width: double.infinity,
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.white
                    ),
                    child: TextField(
                      controller: _controllerDestino,
                      decoration: InputDecoration(
                          icon: Container(
                            margin: EdgeInsets.only(left: 20),
                            width: 10,
                            height: 10,
                            child: Icon(Icons.local_taxi, color: Colors.black,),
                          ),
                          hintText: "Digite o destino",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.only(left: 15, top: 16)
                      ),
                    ),
                  ),
                )
            ),
            Positioned(
              right: 0,
                left: 0,
                bottom: 0,
                child: Padding(
                  padding: Platform.isIOS
                  ? EdgeInsets.fromLTRB(20, 10, 20, 25)
                  : EdgeInsets.all(10),
                  child: ElevatedButton(
                    onPressed: () {
                        _chamarUber();
                    },
                    child: Text(
                      "Chamar Uber",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                        primary: Color(0xff1ebbd8),
                        padding: EdgeInsets.fromLTRB(32, 16, 32, 16)),
                  ),
                ))
          ],
        )
      ),
    );
  }
}
