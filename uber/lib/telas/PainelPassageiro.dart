import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uber/model/Destino.dart';
import 'package:uber/model/Marcador.dart';
import 'package:uber/model/Requisicao.dart';
import 'package:uber/model/Usuario.dart';
import 'package:uber/util/StatusRequisicao.dart';
import 'package:uber/util/UsuarioFirebase.dart';

class PainelPassageiro extends StatefulWidget {
  @override
  _PainelPassageiroState createState() => _PainelPassageiroState();
}

class _PainelPassageiroState extends State<PainelPassageiro> {
  TextEditingController _controllerDestino =
      TextEditingController(text: "Av Paulista, 342");
  Position _localPassageiro;
  Map<String, dynamic> _dadosRequisicao;
  List<String> itensMenu = ["Configurações", "Deslogar"];
  Completer<GoogleMapController> _controller = Completer();
  StreamSubscription<DocumentSnapshot> _streamSubscriptionRequisicoes;

  CameraPosition _posicaoCamera = CameraPosition(
    target: LatLng(-23.563999, -46.653256),
  );

  Set<Marker> _marcadores = {};

  bool _exibirCaixaEnderecoDestino = true;
  String _textoBotao = "Chamar uber";
  Color _corBotao = Color(0xff1ebbd8);
  Function _funcaoBotao;
  String _idRequisicao;

  _escolhaMenuItem(String escolha) {
    switch (escolha) {
      case "Deslogar":
        _deslogarUsuario();
        break;
      case "Configurações":
        break;
    }
  }

  _deslogarUsuario() async {
    FirebaseAuth auth = FirebaseAuth.instance;
    auth.signOut();
    Navigator.pushReplacementNamed(context, "/");
  }

  _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  _adicionarListenerLocalizacao() {
    var geolocator = Geolocator();
    var locationOptions =
        LocationOptions(accuracy: LocationAccuracy.high, distanceFilter: 10);
    geolocator.getPositionStream(locationOptions).listen((position) {
      if (_idRequisicao != null && _idRequisicao.isNotEmpty) {
        //Atualiza local do passageiro
        UsuarioFirebase.atualizarDadosLocalizacao(
            _idRequisicao, position.latitude, position.longitude, "passageiro");
      } else {
        setState(() {
          _localPassageiro = position;
        });
        _statusUberNaoChamado();
      }
    });
  }

  _recuperarUltimaLocalizacaoConhecida() async {
    Position position = await Geolocator()
        .getLastKnownPosition(desiredAccuracy: LocationAccuracy.high);

    setState(() {
      if (position != null) {}
    });
  }

  _movimentarCamera(CameraPosition cameraPosition) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  _exibirMarcadorPassageiro(Position local) async {
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;
    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(devicePixelRatio: pixelRatio),
            "imagens/passageiro.png")
        .then((icone) {
      Marker marcadorPassageiro = Marker(
          markerId: MarkerId("marcador-passageiro"),
          position: LatLng(local.latitude, local.longitude),
          infoWindow: InfoWindow(title: "Meu local"),
          icon: icone);

      setState(() {
        _marcadores.add(marcadorPassageiro);
      });
    });
  }

  _chamarUber() async {
    String enderecoDestino = _controllerDestino.text;
    if (enderecoDestino.isNotEmpty) {
      List<Placemark> listaEnderecos =
          await Geolocator().placemarkFromAddress(enderecoDestino);
      if (listaEnderecos != null && listaEnderecos.length > 0) {
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
        enderecoConfirmacao = "\n Cidade: " + destino.cidade;
        enderecoConfirmacao += "\n Rua: " + destino.rua + ", " + destino.numero;
        enderecoConfirmacao += "\n Bairro: " + destino.bairro;
        enderecoConfirmacao += "\n Cep: " + destino.cep;

        showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text("Confirmação do endereço"),
                content: Text(enderecoConfirmacao),
                contentPadding: EdgeInsets.all(16),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Cancelar",
                        style: TextStyle(color: Colors.red),
                      )),
                  TextButton(
                      onPressed: () {
                        _salvarRequisicao(destino);
                        Navigator.pop(context);
                      },
                      child: Text(
                        "Confirmar",
                        style: TextStyle(color: Colors.red),
                      )),
                ],
              );
            });
      }
    }
  }

  _salvarRequisicao(Destino destino) async {
    Usuario passageiro = await UsuarioFirebase.getDadosUsuarioLogado();
    passageiro.latitude = _localPassageiro.latitude;
    passageiro.longitude = _localPassageiro.longitude;
    Requisicao requisicao = Requisicao();
    requisicao.destino = destino;
    requisicao.passageiro = passageiro;
    requisicao.status = StatusRequisicao.AGUARDANDO;

    Firestore db = Firestore.instance;
    db
        .collection("requisicoes")
        .document(requisicao.id)
        .setData(requisicao.toMap());

    //Salvar requisição ativa
    Map<String, dynamic> dadosRequisicaoAtiva = {};
    dadosRequisicaoAtiva["id_requisicao"] = requisicao.id;
    dadosRequisicaoAtiva["id_usuario"] = passageiro.idUsuario;
    dadosRequisicaoAtiva["status"] = StatusRequisicao.AGUARDANDO;

    db
        .collection("requisicao_ativa")
        .document(passageiro.idUsuario)
        .setData(dadosRequisicaoAtiva);

    //Adicionar listener para as requisições
    if(_streamSubscriptionRequisicoes == null){
      _adicionarListenerRequisicao(requisicao.id);
    }

  }

  _alterarBotaoPrincipal(String texto, Color cor, Function funcao) {
    setState(() {
      _textoBotao = texto;
      _corBotao = cor;
      _funcaoBotao = funcao;
    });
  }

  _statusUberNaoChamado() {
    _exibirCaixaEnderecoDestino = true;
    _alterarBotaoPrincipal(
        "Chamar uber", Color(0xff1ebbd8), () => _chamarUber());

    if(_localPassageiro != null){
      Position position = Position(
          latitude: _localPassageiro.latitude,
          longitude: _localPassageiro.longitude);
      _exibirMarcadorPassageiro(position);
      CameraPosition cameraPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude), zoom: 19);
      _movimentarCamera(cameraPosition);
    }

  }

  _statusAguardando() {
    _exibirCaixaEnderecoDestino = false;
    _alterarBotaoPrincipal("Cancelar", Colors.red, () => _cancelarUber());

    double passageiroLat = _dadosRequisicao["passageiro"]["latitude"];
    double passageiroLon = _dadosRequisicao["passageiro"]["longitude"];
    Position position =
        Position(latitude: passageiroLat, longitude: passageiroLon);
    _exibirMarcadorPassageiro(position);
    CameraPosition cameraPosition = CameraPosition(
        target: LatLng(position.latitude, position.longitude), zoom: 19);
    _movimentarCamera(cameraPosition);
  }

  _statusACaminho() {
    _exibirCaixaEnderecoDestino = false;
    _alterarBotaoPrincipal("Motorista a caminho", Colors.grey, () {});

    double latitudeDestino = _dadosRequisicao["passageiro"]["latitude"];
    double longitudeDestino = _dadosRequisicao["passageiro"]["longitude"];
    double latitudeOrigem = _dadosRequisicao["motorista"]["latitude"];
    double longitudeOrigem = _dadosRequisicao["motorista"]["longitude"];

    Marcador marcadorOrigem = Marcador(
        LatLng(latitudeOrigem,longitudeOrigem),
        "imagens/motorista.png",
        "Local motorista");

    Marcador marcadorDestino = Marcador(
        LatLng(latitudeDestino,longitudeDestino),
        "imagens/destino.png",
        "Local destino");

    _exibirCentralizarDoisMarcadores(marcadorOrigem, marcadorDestino);
  }

  _statusEmViagem(){
    _exibirCaixaEnderecoDestino = false;
    _alterarBotaoPrincipal("Em viagem", Colors.grey, null);
    double latitudeDestino = _dadosRequisicao["destino"]["latitude"];
    double longitudeDestino = _dadosRequisicao["destino"]["longitude"];
    double latitudeOrigem = _dadosRequisicao["motorista"]["latitude"];
    double longitudeOrigem = _dadosRequisicao["motorista"]["longitude"];
    Marcador marcadorOrigem = Marcador(
        LatLng(latitudeOrigem,longitudeOrigem),
        "imagens/motorista.png",
        "Local motorista");

    Marcador marcadorDestino = Marcador(
        LatLng(latitudeDestino,longitudeDestino),
        "imagens/destino.png",
        "Local destino");

    _exibirCentralizarDoisMarcadores(marcadorOrigem, marcadorDestino);

  }

  _statusFinalizada() async{
    //Calcula valor da corrida
    double latitudeDestino = _dadosRequisicao["destino"]["latitude"];
    double longitudeDestino = _dadosRequisicao["destino"]["longitude"];
    double latitudeOrigem = _dadosRequisicao["origem"]["latitude"];
    double longitudeOrigem = _dadosRequisicao["origem"]["longitude"];

    double distanciaEmMetros = await Geolocator().distanceBetween(
        latitudeOrigem,
        longitudeOrigem,
        latitudeDestino,
        longitudeDestino);

    double distanciaKm = distanciaEmMetros / 1000;

    //Valor cobrado por KM  R$ 8
    double valorViagem = distanciaKm * 8;
    var formatar = NumberFormat("#,##0.00", "pt_BR");
    var valorViagemFormatado = formatar.format(valorViagem);

    _alterarBotaoPrincipal("Total - R\$ $valorViagemFormatado", Colors.green, () {
    });

    _marcadores = {};
    Position position = Position(
      latitude: latitudeDestino,
      longitude: longitudeDestino,
    );
    _exibirMarcador(position, "imagens/destino.png", "Destino");
    CameraPosition cameraPosition = CameraPosition(
        target: LatLng(position.latitude, position.longitude), zoom: 19);
    _movimentarCamera(cameraPosition);

  }

  _statusConfirmada(){
    if(_streamSubscriptionRequisicoes != null){
      _streamSubscriptionRequisicoes.cancel();
      _streamSubscriptionRequisicoes = null;
    }

    _exibirCaixaEnderecoDestino = true;
    _alterarBotaoPrincipal(
        "Chamar uber", Color(0xff1ebbd8), () => _chamarUber());

    //Exibe o local do passageiro
    double passageiroLat = _dadosRequisicao["passageiro"]["latitude"];
    double passageiroLon = _dadosRequisicao["passageiro"]["longitude"];
    Position position =
    Position(latitude: passageiroLat, longitude: passageiroLon);
    _exibirMarcadorPassageiro(position);
    CameraPosition cameraPosition = CameraPosition(
        target: LatLng(position.latitude, position.longitude), zoom: 19);
    _movimentarCamera(cameraPosition);

    _dadosRequisicao = {};
  }

  _exibirMarcador(Position local, String icone, String infoWindow) async {
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;
    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio), icone)
        .then((bitmapDescriptor) {
      Marker marcador = Marker(
          markerId: MarkerId(icone),
          position: LatLng(local.latitude, local.longitude),
          infoWindow: InfoWindow(title: infoWindow),
          icon: bitmapDescriptor);

      setState(() {
        _marcadores.add(marcador);
      });
    });
  }

  _exibirCentralizarDoisMarcadores(Marcador marcadorOrigem, Marcador marcadorDestino){
    double latitudeOrigem = marcadorOrigem.local.latitude;
    double longitudeOrigem = marcadorOrigem.local.longitude;
    double latitudeDestino = marcadorDestino.local.latitude;
    double longitudeDestino = marcadorDestino.local.longitude;
    //Exibir dois marcadores
    _exibirDoisMarcadores(marcadorOrigem, marcadorDestino);

    //southwest <= northeast
    var nLat, nLon, sLat, sLon;

    if (latitudeOrigem <= latitudeDestino) {
      sLat = latitudeOrigem;
      nLat = latitudeDestino;
    } else {
      sLat = latitudeDestino;
      nLat = latitudeOrigem;
    }

    if (longitudeOrigem <= longitudeDestino) {
      sLon = longitudeOrigem;
      nLon = longitudeDestino;
    } else {
      sLon = longitudeDestino;
      nLon = longitudeOrigem;
    }
    _movimentarCameraBounds(LatLngBounds(
        southwest: LatLng(sLat, sLon), northeast: LatLng(nLat, nLon)));
  }

  _exibirDoisMarcadores(Marcador marcadorOrigem, Marcador marcadorDestino) {
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;
    LatLng latLngOrigem = marcadorOrigem.local;
    LatLng latLngDestino = marcadorDestino.local;

    Set<Marker> _listaMarcadores = {};

    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(devicePixelRatio: pixelRatio),
            marcadorOrigem.caminhoImagem)
        .then((icone) {
      Marker mOrigem = Marker(
          markerId: MarkerId(marcadorOrigem.caminhoImagem),
          position: LatLng(latLngOrigem.latitude, latLngOrigem.longitude),
          infoWindow: InfoWindow(title: marcadorOrigem.titulo),
          icon: icone);
      _listaMarcadores.add(mOrigem);
    });

    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(devicePixelRatio: pixelRatio),
            marcadorDestino.caminhoImagem)
        .then((icone) {
      Marker mDestino = Marker(
          markerId: MarkerId(marcadorDestino.caminhoImagem),
          position: LatLng(latLngDestino.latitude, latLngDestino.longitude),
          infoWindow: InfoWindow(title: marcadorDestino.titulo),
          icon: icone);
      _listaMarcadores.add(mDestino);
    });

    setState(() {
      _marcadores = _listaMarcadores;
    });
  }

  _movimentarCameraBounds(LatLngBounds latLngBounds) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newLatLngBounds(latLngBounds, 100));
  }

  _cancelarUber() async {
    FirebaseUser firebaseUser = await UsuarioFirebase.getUsuarioAtual();
    Firestore db = Firestore.instance;
    db
        .collection("requisicoes")
        .document(_idRequisicao)
        .updateData({"status": StatusRequisicao.CANCELADA}).then((_) {
      db.collection("requisicao_ativa").document(firebaseUser.uid).delete();
    });

    _statusUberNaoChamado();
    if(_streamSubscriptionRequisicoes != null){
      _streamSubscriptionRequisicoes.cancel();
      _streamSubscriptionRequisicoes = null;
    }
  }

  _recuperaRequisicaoAtiva() async {
    FirebaseUser firebaseUser = await UsuarioFirebase.getUsuarioAtual();
    Firestore db = Firestore.instance;
    DocumentSnapshot documentSnapshot = await db
        .collection("requisicao_ativa")
        .document(firebaseUser.uid)
        .get();

    if (documentSnapshot.data != null) {
      Map<String, dynamic> dados = documentSnapshot.data;
      _idRequisicao = dados["id_requisicao"];
      _adicionarListenerRequisicao(_idRequisicao);
    } else {
      _statusUberNaoChamado();
    }
  }

  _adicionarListenerRequisicao(String idRequisicao) async {
    Firestore db = Firestore.instance;
    _streamSubscriptionRequisicoes = await db
        .collection("requisicoes")
        .document(idRequisicao)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.data != null) {
        Map<String, dynamic> dados = snapshot.data;
        _dadosRequisicao = dados;
        String status = dados["status"];
        _idRequisicao = dados["id"];

        switch (status) {
          case StatusRequisicao.AGUARDANDO:
            _statusAguardando();
            break;
          case StatusRequisicao.A_CAMINHO:
            _statusACaminho();
            break;
          case StatusRequisicao.VIAGEM:
            _statusEmViagem();
            break;
          case StatusRequisicao.FINALIZADA:
            _statusFinalizada();
            break;
          case StatusRequisicao.CONFIRMADA:
            _statusConfirmada();
            break;
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _recuperaRequisicaoAtiva();
    //_recuperarUltimaLocalizacaoConhecida();
    _adicionarListenerLocalizacao();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Painel passageiro"),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) {
              return itensMenu.map((String item) {
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
          Visibility(
              visible: _exibirCaixaEnderecoDestino,
              child: Stack(
                children: [
                  Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: Container(
                          height: 50,
                          width: double.infinity,
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(3),
                              color: Colors.white),
                          child: TextField(
                            readOnly: true,
                            decoration: InputDecoration(
                                icon: Container(
                                  margin: EdgeInsets.only(left: 20),
                                  width: 10,
                                  height: 10,
                                  child: Icon(
                                    Icons.location_on,
                                    color: Colors.green,
                                  ),
                                ),
                                hintText: "Meu local",
                                border: InputBorder.none,
                                contentPadding:
                                    EdgeInsets.only(left: 15, top: 16)),
                          ),
                        ),
                      )),
                  Positioned(
                      top: 55,
                      left: 0,
                      right: 0,
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: Container(
                          height: 50,
                          width: double.infinity,
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(3),
                              color: Colors.white),
                          child: TextField(
                            controller: _controllerDestino,
                            decoration: InputDecoration(
                                icon: Container(
                                  margin: EdgeInsets.only(left: 20),
                                  width: 10,
                                  height: 10,
                                  child: Icon(
                                    Icons.local_taxi,
                                    color: Colors.black,
                                  ),
                                ),
                                hintText: "Digite o destino",
                                border: InputBorder.none,
                                contentPadding:
                                    EdgeInsets.only(left: 15, top: 16)),
                          ),
                        ),
                      )),
                ],
              )),
          Positioned(
              right: 0,
              left: 0,
              bottom: 0,
              child: Padding(
                padding: Platform.isIOS
                    ? EdgeInsets.fromLTRB(20, 10, 20, 25)
                    : EdgeInsets.all(10),
                child: ElevatedButton(
                  onPressed: _funcaoBotao,
                  child: Text(
                    _textoBotao,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                      primary: _corBotao,
                      padding: EdgeInsets.fromLTRB(32, 16, 32, 16)),
                ),
              ))
        ],
      )),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _streamSubscriptionRequisicoes.cancel();
    _streamSubscriptionRequisicoes = null;
  }
}
