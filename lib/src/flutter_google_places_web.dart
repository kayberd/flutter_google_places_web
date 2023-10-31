import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_google_places_web/src/search_results_tile.dart';
import 'package:uuid/uuid.dart';

class FlutterGooglePlacesWeb extends StatefulWidget {
  ///[value] stores the clicked address data in
  ///FlutterGooglePlacesWeb.value['name'] = '1600 Amphitheatre Parkway, Mountain View, CA, USA';
  ///FlutterGooglePlacesWeb.value['streetAddress'] = '1600 Amphitheatre Parkway';
  ///FlutterGooglePlacesWeb.value['city'] = 'CA';
  ///FlutterGooglePlacesWeb.value['country'] = 'USA';
  static Map<String, String?>? value;

  ///[showResults] boolean shows results container
  static bool showResults = false;

  ///This is the API Key that is needed to communicate with google places API
  ///Get API Key: https://developers.google.com/places/web-service/get-api-key
  final String? apiKey;

  ///Proxy to be used if having CORS XMLError or want to use for security
  final String? proxyURL;

  ///The position, in the input term, of the last character that the service uses to match predictions.
  ///For example, if the input is 'Google' and the [offset] is 3, the service will match on 'Goo'.
  ///The string determined by the [offset] is matched against the first word in the input term only.
  ///For example, if the input term is 'Google abc' and the [offset] is 3, the service will attempt to match against 'Goo abc'.
  ///If no [offset] is supplied, the service will use the whole term. The [offset] should generally be set to the position of the text caret.
  // final int? offset;

  ///[sessionToken] is a boolean that enable/disables a UUID v4 session token. [sessionToken] is [true] by default.
  ///Google recommends using session tokens for all autocomplete sessions
  ///Read more about session tokens https://developers.google.com/places/web-service/session-tokens
  // final bool sessionToken;

  ///Currently, you can use components to filter by up to 5 countries.
  ///Countries must be passed as a two character, ISO 3166-1 Alpha-2 compatible country code.
  ///For example: components=country:fr would restrict your results to places within France.
  ///Multiple countries must be passed as multiple country:XX filters, with the pipe character (|) as a separator.
  ///For example: components=country:us|country:pr|country:vi|country:gu|country:mp would restrict your results to places within the United States and its unincorporated organized territories.
  final String? components;

  final InputDecoration? decoration;
  final bool? required;
  final Function? onSelected;
  final String? initialValue;
  final TextEditingController controller;
  final Map<String, dynamic>? headers;
  final String? language;

  FlutterGooglePlacesWeb(
      {Key? key,
      this.apiKey,
      this.proxyURL,
      this.decoration,
        this.components,
      this.required,
      this.onSelected,
      this.initialValue,
      required this.controller,
      this.headers,
      this.language
      });

  @override
  FlutterGooglePlacesWebState createState() => FlutterGooglePlacesWebState();
}

class FlutterGooglePlacesWebState extends State<FlutterGooglePlacesWeb> {
  List<Address> displayedResults = [];
  String? url;
  Timer? debounceTimer;
  var uuid = Uuid();
  final addressFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    if (widget.initialValue != null) widget.controller.text = widget.initialValue!;
    FlutterGooglePlacesWeb.value = {};
    super.initState();
  }

  @override
  void dispose() {
    widget.controller.dispose();
    debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Flex(
      direction: Axis.vertical,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: Container(
            alignment: Alignment.center,
            child: Stack(
              children: [
                //search field
                TextFormField(
                  key: widget.key,
                  controller: widget.controller,
                  decoration: widget.decoration,
                  validator: (value) {
                    if (widget.required == true && value!.isEmpty) {
                      return 'Please enter an address';
                    }
                    return null;
                  },
                  onChanged: (text) async {
                    debounceTimer?.cancel();
                    debounceTimer = Timer(
                      Duration(milliseconds: 750),
                      () async {
                        if (text.length > 3) await _getLocationResults(text);
                        if (mounted) {
                          setState(() {});
                        }
                      },
                    );
                  },
                ),
                FlutterGooglePlacesWeb.showResults
                    ? Padding(
                        padding: EdgeInsets.only(top: 50),
                        child: Container(
                          width: MediaQuery.of(context).size.width,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                fit: FlexFit.loose,
                                child: displayedResults.isEmpty
                                    ? Container(
                                        padding: EdgeInsets.only(top: 102, bottom: 102),
                                        child: CircularProgressIndicator(strokeWidth: 6.0),
                                      )
                                    : ListView(
                                        shrinkWrap: true,
                                        children: displayedResults
                                            .map((Address addressData) => SearchResultsTile(addressData: addressData, callback: _selectResult, address: FlutterGooglePlacesWeb.value))
                                            .toList(),
                                      ),
                              ),
                            ],
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey[200]!, width: 0.5),
                          ),
                        ),
                      )
                    : Container(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<List<Address>> _getLocationResults(String inputText) async {
    if (inputText.isEmpty) {
      setState(() {
        FlutterGooglePlacesWeb.showResults = false;
      });
    } else {
      setState(() {
        FlutterGooglePlacesWeb.showResults = true;
      });
    }

    const baseURL = 'https://maps.googleapis.com/maps/api/place/autocomplete/json';
    final input = Uri.encodeComponent(inputText);
    if (widget.proxyURL == null) {
      url = '$baseURL?input=$input&key=${widget.apiKey}&type=address';
      if(widget.components != null){
        url = url! + '&components=${widget.components}';
      }
    } else {
      url = '${widget.proxyURL}?input=$input';
    }
    if(widget.language != null){
      url = url! + '&language=${widget.language}';
    }
    Response response = await Dio().get(url!, options: Options(headers: widget.headers));
    var predictions = response.data['predictions'];
    if (predictions != []) {
      displayedResults.clear();
    }

    for (var i = 0; i < predictions.length; i++) {
      String? placeId = predictions[i]['place_id'];
      String? name = predictions[i]['description'];
      String? streetAddress = predictions[i]['structured_formatting']['main_text'];
      List<dynamic> terms = predictions[i]['terms'];
      String? city = terms[terms.length - 2]['value'];
      String? country = terms[terms.length - 1]['value'];
      displayedResults.add(Address(
        placeId: placeId,
        name: name,
        streetAddress: streetAddress,
        city: city,
        country: country,
      ));
    }

    return displayedResults;
  }

  void _selectResult(Address clickedAddress) {
    widget.onSelected?.call(clickedAddress.placeId);
    setState(() {
      FlutterGooglePlacesWeb.showResults = false;
      widget.controller.text = clickedAddress.name!;
      FlutterGooglePlacesWeb.value!['name'] = clickedAddress.name;
      FlutterGooglePlacesWeb.value!['streetAddress'] = clickedAddress.streetAddress;
      FlutterGooglePlacesWeb.value!['city'] = clickedAddress.city;
      FlutterGooglePlacesWeb.value!['country'] = clickedAddress.country;
    });
  }
}

class Address {
  String? placeId;
  String? name;
  String? streetAddress;
  String? city;
  String? country;

  Address({this.placeId, this.name, this.streetAddress, this.city, this.country});
}
