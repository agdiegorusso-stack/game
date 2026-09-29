part of 'app.dart';
const ink=Color(0xFF0B100E), panel=Color(0xFF17221C), lime=Color(0xFFC4EE79), muted=Color(0xFFAAB8AC);
final forgeTheme=ThemeData(useMaterial3:true, brightness:Brightness.dark, scaffoldBackgroundColor:ink,
  colorScheme:ColorScheme.fromSeed(seedColor:lime,brightness:Brightness.dark,primary:lime,onPrimary:ink,surface:panel,onSurface:const Color(0xFFF0F4EB)),
  inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:const Color(0xFF101913),border:OutlineInputBorder(borderRadius:BorderRadius.circular(14)),contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:14)),
  filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(minimumSize:const Size(0,52),textStyle:const TextStyle(fontSize:16,fontWeight:FontWeight.w700),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)))),
  textTheme:const TextTheme(headlineLarge:TextStyle(fontSize:34,fontWeight:FontWeight.w800,letterSpacing:-1.2),headlineMedium:TextStyle(fontSize:27,fontWeight:FontWeight.w800,letterSpacing:-0.8),titleLarge:TextStyle(fontSize:22,fontWeight:FontWeight.w700),titleMedium:TextStyle(fontSize:17,fontWeight:FontWeight.w700),bodyLarge:TextStyle(fontSize:16,height:1.4),bodyMedium:TextStyle(fontSize:14,height:1.35)));
class FCard extends StatelessWidget {
  final Widget child; final EdgeInsetsGeometry padding; final Color? color;
  const FCard({super.key,required this.child,this.padding=const EdgeInsets.all(18),this.color});
  @override Widget build(BuildContext context)=>Container(padding:padding,decoration:BoxDecoration(color:color??panel,borderRadius:BorderRadius.circular(22),border:Border.all(color:Colors.white.withValues(alpha:.07))),child:child);
}
class SectionTitle extends StatelessWidget {
  final String title; final String? subtitle; final Widget? trailing;
  const SectionTitle(this.title,{super.key,this.subtitle,this.trailing});
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(top:22,bottom:12),child:Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:Theme.of(context).textTheme.titleLarge),if(subtitle!=null)Padding(padding:const EdgeInsets.only(top:4),child:Text(subtitle!,style:const TextStyle(color:muted)))])),if(trailing!=null)trailing!]));
}
class Stat extends StatelessWidget {
  final String value,label; const Stat(this.value,this.label,{super.key});
  @override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(value,style:const TextStyle(fontSize:28,fontWeight:FontWeight.w800,letterSpacing:-1)),const SizedBox(height:4),Text(label,style:const TextStyle(color:muted,fontSize:12))]);
}
class EmptyPanel extends StatelessWidget {
  final IconData icon;final String title,body;final Widget? action;
  const EmptyPanel({super.key,required this.icon,required this.title,required this.body,this.action});
  @override Widget build(BuildContext context)=>FCard(child:Column(children:[Icon(icon,size:42,color:lime),const SizedBox(height:16),Text(title,style:Theme.of(context).textTheme.titleLarge,textAlign:TextAlign.center),const SizedBox(height:8),Text(body,textAlign:TextAlign.center,style:const TextStyle(color:muted)),if(action!=null)Padding(padding:const EdgeInsets.only(top:18),child:action!)]));
}
class RestBar extends StatelessWidget {
  final RestClock timer;const RestBar({super.key,required this.timer});
  @override Widget build(BuildContext context)=>AnimatedBuilder(animation:timer,builder:(c,_) {
    if(!timer.visible)return const SizedBox.shrink();
    return Material(color:const Color(0xFF263B27),child:SafeArea(top:false,child:Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:6),child:Row(children:[
      const Icon(Icons.timer_outlined,color:lime),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[Text(timer.remaining==0?'Tempo concluso':timer.label,style:const TextStyle(fontSize:12,color:muted)),Text(clock(timer.remaining),style:const TextStyle(fontSize:25,fontWeight:FontWeight.w800))])),
      IconButton(tooltip:timer.paused?'Riprendi':'Pausa',onPressed:timer.remaining>0?timer.toggle:null,icon:Icon(timer.paused?Icons.play_arrow:Icons.pause)),TextButton(onPressed:()=>timer.add(30),child:const Text('+30 s')),IconButton(tooltip:'Chiudi timer',onPressed:timer.clear,icon:const Icon(Icons.close))
    ]))));
  });
}
