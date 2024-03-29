import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uber/model/Usuario.dart';
import 'package:uber/util/StatusRequisicao.dart';
import 'package:uber/util/UsuarioFirebase.dart';

class Corrida extends StatefulWidget {
  String idRequisicao;
  Corrida(this.idRequisicao);

  @override
  _CorridaState createState() => _CorridaState();
}

class _CorridaState extends State<Corrida> {
  Completer<GoogleMapController> _controller = Completer();
  Set<Marker> _marcadores = {};
  Map<String, dynamic> _dadosRequisicao;
  String _mensagemStatus = "";
  String _idRequisicao;
  Position _localMotorista;
  String _statusRequisicao = StatusRequisicao.AGUARDANDO;

  CameraPosition _posicaoCamera = CameraPosition(
    target: LatLng(-23.563999, -46.653256),
  );

  String _textoBotao = "Aceitar corrida";
  Color _corBotao = Color(0xff1ebbd8);
  Function _funcaoBotao;

  _alterarBotaoPrincipal(String texto, Color cor, Function funcao) {
    setState(() {
      _textoBotao = texto;
      _corBotao = cor;
      _funcaoBotao = funcao;
    });
  }

  _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  _adicionarListenerLocalizacao() {
    var geolocator = Geolocator();
    var locationOptions =
        LocationOptions(accuracy: LocationAccuracy.high, distanceFilter: 10);
    geolocator.getPositionStream(locationOptions).listen((position) {
      if (position != null) {
        if (_idRequisicao != null && _idRequisicao.isNotEmpty) {
          if (_statusRequisicao != StatusRequisicao.AGUARDANDO) {
            //Atualiza local do motorista
            UsuarioFirebase.atualizarDadosLocalizacao(
                _idRequisicao, position.latitude, position.longitude, "motorista");
          } else {
            setState(() {
              _localMotorista = position;
            });
            _statusAguardando();
          }
        }
      }
    });
  }

  _recuperarUltimaLocalizacaoConhecida() async {
    Position position = await Geolocator()
        .getLastKnownPosition(desiredAccuracy: LocationAccuracy.high);

    if (position != null) {
      //Atualizar a localização em tempo real
    }
  }

  _movimentarCamera(CameraPosition cameraPosition) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
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

  _recuperarRequisicao() async {
    String idRequisicao = widget.idRequisicao;
    Firestore db = Firestore.instance;
    DocumentSnapshot documentSnapshot =
        await db.collection("requisicoes").document(idRequisicao).get();
    _dadosRequisicao = documentSnapshot.data;
  }

  _adicionarListenerRequisicao() async {
    Firestore db = Firestore.instance;
    await db
        .collection("requisicoes")
        .document(_idRequisicao)
        .snapshots()
        .listen((event) {
      if (event.data != null) {
        _dadosRequisicao = event.data;

        Map<String, dynamic> dados = event.data;
        _statusRequisicao = dados["status"];

        switch (_statusRequisicao) {
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

  _statusAguardando() {
    _alterarBotaoPrincipal("Aceitar corrida", Color(0xff1ebbd8), () {
      _aceitarCorrida();
    });

    if (_localMotorista != null) {
      double motoristaLat = _localMotorista.latitude;
      double motoristaLon = _localMotorista.longitude;
      Position position = Position(
        latitude: motoristaLat,
        longitude: motoristaLon,
      );
      _exibirMarcador(position, "imagens/motorista.png", "Motorista");
      CameraPosition cameraPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude), zoom: 19);
      _movimentarCamera(cameraPosition);
    }
  }

  _statusACaminho() {
    _mensagemStatus = "A caminho do passageiro";
    _alterarBotaoPrincipal("Iniciar corrida", Color(0xff1ebbd8), () {
      _iniciarCorrida();
    });
    double latitudePassageiro = _dadosRequisicao["passageiro"]["latitude"];
    double longitudePassageiro = _dadosRequisicao["passageiro"]["longitude"];
    double latitudeMotorista = _dadosRequisicao["motorista"]["latitude"];
    double longitudeMotorista = _dadosRequisicao["motorista"]["longitude"];

    //Exibir dois marcadores
    _exibirDoisMarcadores(LatLng(latitudeMotorista, longitudeMotorista),
        LatLng(latitudePassageiro, longitudePassageiro));

    //southwest <= northeast
    var nLat, nLon, sLat, sLon;

    if (latitudeMotorista <= latitudePassageiro) {
      sLat = latitudeMotorista;
      nLat = latitudePassageiro;
    } else {
      sLat = latitudePassageiro;
      nLat = latitudeMotorista;
    }

    if (longitudeMotorista <= longitudePassageiro) {
      sLon = longitudeMotorista;
      nLon = longitudePassageiro;
    } else {
      sLon = longitudePassageiro;
      nLon = longitudeMotorista;
    }
    _movimentarCameraBounds(LatLngBounds(
        southwest: LatLng(sLat, sLon), northeast: LatLng(nLat, nLon)));
  }

  _statusEmViagem() {
    _mensagemStatus = "Em viagem";
    _alterarBotaoPrincipal("Finalizar corrida", Color(0xff1ebbd8), () {
      _finalizarCorrida();
    });
    double latitudeDestino = _dadosRequisicao["destino"]["latitude"];
    double longitudeDestino = _dadosRequisicao["destino"]["longitude"];
    double latitudeOrigem = _dadosRequisicao["motorista"]["latitude"];
    double longitudeOrigem = _dadosRequisicao["motorista"]["longitude"];

    //Exibir dois marcadores
    _exibirDoisMarcadores(LatLng(latitudeOrigem, longitudeOrigem),
        LatLng(latitudeDestino, longitudeDestino));

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


    _mensagemStatus = "Viagem finalizada";
    _alterarBotaoPrincipal("Confirmar - R\$ $valorViagemFormatado", Color(0xff1ebbd8), () {
      _confirmarCorrida();
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
    Navigator.pushReplacementNamed(context, "/painel-motorista");
  }

  _confirmarCorrida(){
    Firestore db = Firestore.instance;
    db.collection("requisicoes").document(_idRequisicao).updateData({
      "status": StatusRequisicao.CONFIRMADA
    });

    String idPassageiro = _dadosRequisicao["passageiro"]["idUsuario"];
    db
        .collection("requisicao_ativa")
        .document(idPassageiro)
        .delete();

    String idMotorista = _dadosRequisicao["motorista"]["idUsuario"];
    db
        .collection("requisicao_ativa_motorista")
        .document(idMotorista)
        .delete();
  }

  _finalizarCorrida() {
    Firestore db = Firestore.instance;
    db
        .collection("requisicoes")
        .document(_idRequisicao)
        .updateData({"status": StatusRequisicao.FINALIZADA});

    String idPassageiro = _dadosRequisicao["passageiro"]["idUsuario"];
    db
        .collection("requisicao_ativa")
        .document(idPassageiro)
        .updateData({"status": StatusRequisicao.FINALIZADA});

    String idMotorista = _dadosRequisicao["motorista"]["idUsuario"];
    db
        .collection("requisicao_ativa_motorista")
        .document(idMotorista)
        .updateData({"status": StatusRequisicao.FINALIZADA});
  }

  _iniciarCorrida() {
    Firestore db = Firestore.instance;
    db.collection("requisicoes").document(_idRequisicao).updateData({
      "origem": {
        "latitude": _dadosRequisicao["motorista"]["latitude"],
        "longitude": _dadosRequisicao["motorista"]["longitude"],
      },
      "status": StatusRequisicao.VIAGEM
    });

    String idPassageiro = _dadosRequisicao["passageiro"]["idUsuario"];
    db
        .collection("requisicao_ativa")
        .document(idPassageiro)
        .updateData({"status": StatusRequisicao.VIAGEM});

    String idMotorista = _dadosRequisicao["motorista"]["idUsuario"];
    db
        .collection("requisicao_ativa_motorista")
        .document(idMotorista)
        .updateData({"status": StatusRequisicao.VIAGEM});
  }

  _movimentarCameraBounds(LatLngBounds latLngBounds) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newLatLngBounds(latLngBounds, 100));
  }

  _exibirDoisMarcadores(LatLng latLng1, LatLng latLng2) {
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;
    Set<Marker> _listaMarcadores = {};

    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(devicePixelRatio: pixelRatio),
            "imagens/motorista.png")
        .then((icone) {
      Marker marcadorMotorista = Marker(
          markerId: MarkerId("marcador-motorista"),
          position: LatLng(latLng1.latitude, latLng1.longitude),
          infoWindow: InfoWindow(title: "Local motorista"),
          icon: icone);
      _listaMarcadores.add(marcadorMotorista);
    });

    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(devicePixelRatio: pixelRatio),
            "imagens/passageiro.png")
        .then((icone) {
      Marker marcadorPassageiro = Marker(
          markerId: MarkerId("marcador-passageiro"),
          position: LatLng(latLng2.latitude, latLng2.longitude),
          infoWindow: InfoWindow(title: "Local passageiro"),
          icon: icone);
      _listaMarcadores.add(marcadorPassageiro);
    });

    setState(() {
      _marcadores = _listaMarcadores;
    });
  }

  _aceitarCorrida() async {
    Usuario motorista = await UsuarioFirebase.getDadosUsuarioLogado();
    motorista.latitude = _localMotorista.latitude;
    motorista.longitude = _localMotorista.longitude;

    Firestore db = Firestore.instance;
    String idRequisicao = _dadosRequisicao["id"];

    db.collection("requisicoes").document(idRequisicao).updateData({
      "motorista": "",
      "status": StatusRequisicao.A_CAMINHO,
    }).then((_) {
      //Atualiza requisição ativa
      String idPassageiro = _dadosRequisicao["passageiro"]["idUsuario"];
      db
          .collection("requisicao_ativa")
          .document(idPassageiro)
          .updateData({"status": StatusRequisicao.A_CAMINHO});

      //Salvar requisição ativa para motorista

      String idMotorista = motorista.idUsuario;
      db
          .collection("requisicao_ativa_motorista")
          .document(idMotorista)
          .setData({
        "id_requisicao": idRequisicao,
        "id_usuario": idMotorista,
        "status": StatusRequisicao.A_CAMINHO
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _idRequisicao = widget.idRequisicao;
    // adicionar listener para mudanças de requisição
    _adicionarListenerRequisicao();
    //_recuperarUltimaLocalizacaoConhecida();
    _adicionarListenerLocalizacao();

    //_recuperarRequisicao();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Painel corrida - ${_mensagemStatus}"),
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
}
