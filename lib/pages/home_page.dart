import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final searchCtrl = TextEditingController();


  bool isLoading = false;
  String? error;
  String? resolvedCity;

  //current data variable
  double? _cTemp;
  double? _cWindKph;
  int? _wCode;
  String? _wText;

  //2 list for hourly and daily
  List<_Hourly> hourlies = [];
  List<_Daily> dailies = [];

  //------------- network ------------//

  //latitute and lonlitude
  Future<({String city, num lat, num lon})> geoLocation(String city) async {
    Uri uri = Uri.parse(
      "https://geocoding-api.open-meteo.com/v1/search?name=$city&count=1&format=json",
    );
    final response = await http.get(uri);
    if (response.statusCode != 200)
      throw Exception('Geocoding is failed${response.statusCode}');
    final decodedData = jsonDecode(response.body) as Map<String, dynamic>;

    final result = (decodedData['results'] as List?) ?? [];
    if (result.isEmpty) throw Exception("City not found");

    final allData = result.first as Map<String, dynamic>;
    final lat = allData['latitude'] as num;
    final lon = allData['longitude'] as num;
    final name = "${allData['name']},${allData['country']}";

    return (city: name, lon: lon, lat: lat);
  }

  //second time
  Future<void> fetchData(String city) async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final geoData = await geoLocation(city);

      Uri uri = Uri.parse(
        "https://api.open-meteo.com/v1/forecast?latitude=${geoData.lat}&longitude=${geoData.lon}&daily=temperature_2m_max,temperature_2m_min,sunset,sunrise&hourly=temperature_2m,weather_code,wind_speed_10m&current=temperature_2m,weather_code,wind_speed_10m&timezone=auto",
      );

      final response = await http.get(uri);
      if (response.statusCode != 200)
        throw Exception("weather relaod failed ${response.statusCode} ");
      final decodedData = jsonDecode(response.body);

      //current weather data
      final currentWeather = decodedData['current'] as Map<String, dynamic>;
      final cTemp = currentWeather['temperature_2m'] as double;
      final cWindSpeed = currentWeather['wind_speed_10m'] as double;
      final wCode = currentWeather['weather_code'] as int;
      //  final wText = currentWeather['weather_code'].toString();

      //hourley weather deta
      final hourlyWeather = decodedData['hourly'] as Map<String, dynamic>;
      final hTimes = List<String>.from(hourlyWeather['time'] as List);
      final hTemp = List<double>.from(hourlyWeather['temperature_2m'] as List);
      final hCodes = List<int>.from(hourlyWeather['weather_code'] as List);

      //daily
      final dailyWeather = decodedData['daily'] as Map<String, dynamic>;
      final dTimes = List<String>.from(dailyWeather['time'] as List);
      final dMaxTemp = List<double>.from(dailyWeather['temperature_2m_max'] as List);
      final dMinTemp = List<double>.from(dailyWeather['temperature_2m_min'] as List);

      final outHourly = <_Hourly>[];

      for (var i = 0; i < hTimes.length; i++) {
        outHourly.add(
          _Hourly(
            time: DateTime.parse(hTimes[i]),
            temp: (hTemp[i].toDouble()),
            code: (hCodes[i].toInt()),
          ),
        );

        final outDaily = <_Daily>[];

        for (var i = 0; i < dTimes.length; i++) {
          outDaily.add(
            _Daily(
              time: DateTime.parse(hTimes[i]),
              minTemp: (dMinTemp[i].toDouble()),
              maxTemp: (dMaxTemp[i]).toDouble()),
          );


          setState(() {
          resolvedCity = geoData.city;
          _cTemp = cTemp;
          _cWindKph = cWindSpeed;
          _wCode = wCode;
          _wText = _codeToText(wCode);
          hourlies = outHourly;
          dailies = outDaily;
        });}
      }
    } catch (e) {
      print(e.toString());
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  String _codeToText(int? c) {
    if (c == 0) return "--";
    if ([1, 2, 3].contains(c)) return "Clear Sky";
    if ([45, 48].contains(c)) return "Mainly clear";
    if ([51, 52, 53, 54, 55, 56, 57].contains(c)) return "Fog";
    if ([61, 62, 63, 64, 65, 66, 67].contains(c)) return "Drizzle";
    if ([71, 72, 73, 74, 75, 76, 77].contains(c)) return "Rain";
    if ([80, 81, 82].contains(c)) return "Snow";
    if ([85, 86].contains(c)) return "Rain Showers";
    if (c == 95) return "Thunderstorm";
    if (c == 96) return "Thunderstorm Sky";
    return "Cloudy";
  }


  IconData _codeToIcon(int?c){
    if(c==0) return Icons.sunny;
    if([1,2,3].contains(c)) return Icons.cloud_outlined;
    if([45,48].contains(c)) return Icons.foggy;
    if([51, 52, 53, 54, 55, 56, 57].contains(c)) return Icons.grain_sharp;
    if([61, 62, 63, 64, 65, 66, 67].contains(c)) return Icons.water_drop;
    if([71, 72, 73, 74, 75, 76, 77].contains(c)) return Icons.ac_unit;
    if([80,81,82].contains(c)) return Icons.snowing;
    if([85,86].contains(c)) return Icons.deblur_outlined;
    if(c==95) return Icons.thunderstorm;
    if(c==96) return Icons.thunderstorm;
    return Icons.cloud;
  }




  @override
  void initState() {
    fetchData(searchCtrl.text);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
 
    var bottomTextStyle = TextStyle(fontWeight: FontWeight.bold,fontSize: 20,color: Colors.white,);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade900, Colors.blue.shade500, Colors.white],
          ),
        ),
        child:  ListView(
          padding: EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchCtrl,
                    onSubmitted: (value) => fetchData(value),
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Enter city name",
                      labelStyle: TextStyle(color: Colors.white),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8,),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      backgroundColor: Colors.blue.shade400,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: isLoading
                        ? null
                        : () => fetchData(searchCtrl.text),
                    child: Icon(Icons.search_rounded,size: 20,),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
              SizedBox(
                  height: 200,
                  child: Image.asset('asset/weather.png',)),
              //error
              if (error != null)
                Text(error!, style: TextStyle(color: Colors.red)),
              const SizedBox(height: 12,),
              Column(
                children: [
                  Text('YOUR LOCATION',style: TextStyle(color: Colors.white,fontSize: 12),),
                  Text(resolvedCity ?? "",style: TextStyle(color: Colors.white,fontSize: 20),),
                ],
              ),
              //current temp
              if (_cTemp != null)
                Center(child: Text("${_cTemp!.toStringAsFixed(0)}°C",style: TextStyle(fontWeight: FontWeight.bold,fontSize: 75),)),
              //current wind kph
              if(_cWindKph != null)
                Card(
                  color: Colors.pink.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Row(
                      children: [
                        Text("Sunny conditions likely through today wind up to ",style: TextStyle(color: Colors.black87),),
                        Text("$_cWindKph km/h",style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 10,),

              if(hourlies.isNotEmpty)
                Card(
                  color: Colors.blue[600],
                  elevation: 10,
                  child: SizedBox(
                      height: 100,
                      child: ListView.separated(
                        itemCount: hourlies.length,
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (context, index) => SizedBox(height: 12,),
                        separatorBuilder:(context, index) {
                          final h = hourlies[index];
                          final label = index == 0 ? "Now": h.time.hour.toString();
                          return Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(label,style: TextStyle(color: Colors.white),),
                                Icon(_codeToIcon(h.code),color: Colors.white,),
                                Text(h.temp.toString(),style: TextStyle(color: Colors.white),),
                              ],
                            ),
                          );
                        } ,
                      )
                  ),
                ),
              const SizedBox(height: 5,),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Row(
                  children: [
                    Text('Hourly',style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                    ),),
                    Spacer(),
                    Icon(Icons.menu_open_sharp,color: Colors.white,),
                  ],
                ),
              ),
              const SizedBox(height: 5,),
              if(dailies.isNotEmpty)
                Card(
                  color: Colors.blue.shade200,
                  elevation: 20,
                  child: SizedBox(
                      height: 200,
                      child: ListView.separated(
                        scrollDirection: Axis.vertical,
                        itemCount: dailies.length,
                        itemBuilder: (context, index) {
                          return SizedBox(height: 20,);
                        },
                        separatorBuilder: (context, index) {
                          final d = dailies[index];
                          String formatted = DateFormat('dd MMM yyyy').format(d.time);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal:20),
                            child: Card(
                              color: Colors.blue.shade500,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 15,right: 15,top: 15,bottom: 10),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(formatted,style: TextStyle(fontSize: 20,color: Colors.grey.shade200),),
                                    Row(
                                      children: [
                                        SizedBox(height: 35,child: Image.asset('asset/hot.png')),
                                        Text(d.minTemp.toString(),style: bottomTextStyle,),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        SizedBox( height: 30,child: Image.asset('asset/sun.png')),
                                        const SizedBox(width: 5,),
                                        Text(d.maxTemp.toString(),style: bottomTextStyle,)
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      )
                  ),
                )

          ],
        ),
      ),
    );
  }
}




class _Hourly {
  final DateTime time;
  final double temp;
  final int code;

  _Hourly({required this.time, required this.temp, required this.code});
}

class _Daily {
  final DateTime time;
  final double minTemp;
  final double maxTemp;

  _Daily({required this.time, required this.minTemp, required this.maxTemp});
}
