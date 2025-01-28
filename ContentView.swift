import SwiftUI

    struct ContentView: View {
        @State private var showSplashScreen = true

        var body: some View {
            ZStack {
                if showSplashScreen {
                    SplashScreenView()
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    showSplashScreen = false
                                }
                            }
                        }
                } else {
                    MainAppView()
                }
            }
        }
    }

    struct SplashScreenView: View {
        var body: some View {
            VStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                Text("TimeSync")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
        }
    }

    struct MainAppView: View {
        var body: some View {
            NavigationStack {
                List {
                    NavigationLink(destination: TimezoneInputViewController()) {
                        Text("Timezone Settings")
                    }
                }
                .navigationTitle("Time Management")
            }
        }
    }

    struct ContentView_Previews: PreviewProvider {
        static var previews: some View {
            ContentView()
        }
    }
